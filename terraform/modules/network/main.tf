data "aws_kms_alias" "cloudwatch" {
  count = var.enable_kms_hardening ? 1 : 0
  name  = "alias/aws/logs"
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.common_tags, {
    Name      = "${var.name_prefix}-vpc"
    Component = "network"
  })
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/aws/vpc/${var.name_prefix}/flow-logs"
  kms_key_id        = var.enable_kms_hardening ? data.aws_kms_alias.cloudwatch[0].target_key_arn : null
  retention_in_days = 365

  tags = merge(var.common_tags, {
    Name      = "${var.name_prefix}-flow-logs"
    Component = "network"
  })
}

resource "aws_iam_role" "flow_logs" {
  name = "${var.name_prefix}-vpc-flow-logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name      = "${var.name_prefix}-vpc-flow-logs"
    Component = "network"
  })
}

resource "aws_iam_role_policy" "flow_logs" {
  name = "${var.name_prefix}-vpc-flow-logs"
  role = aws_iam_role.flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
        ]
        Resource = "${aws_cloudwatch_log_group.flow_logs.arn}:*"
      }
    ]
  })
}

resource "aws_flow_log" "this" {
  iam_role_arn         = aws_iam_role.flow_logs.arn
  log_destination      = aws_cloudwatch_log_group.flow_logs.arn
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.this.id
  log_destination_type = "cloud-watch-logs"

  tags = merge(var.common_tags, {
    Name      = "${var.name_prefix}-vpc-flow-log"
    Component = "network"
  })
}

resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.common_tags, {
    Name      = "${var.name_prefix}-default-sg"
    Component = "network"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.common_tags, {
    Name      = "${var.name_prefix}-igw"
    Component = "network"
  })
}

resource "aws_subnet" "public" {
  for_each = { for idx, cidr in var.public_subnet_cidrs : tostring(idx) => cidr }

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  availability_zone       = var.public_subnet_azs[tonumber(each.key)]
  map_public_ip_on_launch = true

  tags = merge(var.common_tags, {
    Name                                            = "${var.name_prefix}-public-${tonumber(each.key) + 1}"
    Component                                       = "network"
    Tier                                            = "public"
    "kubernetes.io/role/elb"                        = "1"
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  })
}

resource "aws_subnet" "private" {
  for_each = { for idx, cidr in var.private_subnet_cidrs : tostring(idx) => cidr }

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = var.private_subnet_azs[tonumber(each.key)]

  tags = merge(var.common_tags, {
    Name                                            = "${var.name_prefix}-private-${tonumber(each.key) + 1}"
    Component                                       = "network"
    Tier                                            = "private"
    "kubernetes.io/role/internal-elb"               = "1"
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  })
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(var.common_tags, {
    Name      = "${var.name_prefix}-nat-eip"
    Component = "network"
  })
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public["0"].id

  tags = merge(var.common_tags, {
    Name      = "${var.name_prefix}-nat"
    Component = "network"
  })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(var.common_tags, {
    Name      = "${var.name_prefix}-public-rt"
    Component = "network"
  })
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  tags = merge(var.common_tags, {
    Name      = "${var.name_prefix}-private-rt"
    Component = "network"
  })
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}
