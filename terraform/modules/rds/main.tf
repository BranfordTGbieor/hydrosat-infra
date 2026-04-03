data "aws_kms_alias" "rds" {
  name = "alias/aws/rds"
}

resource "aws_security_group" "this" {
  name        = "${var.name_prefix}-rds"
  description = "Security group for Dagster metadata RDS"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from EKS nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.allowed_security_group]
  }

  egress {
    description      = "Database egress required for managed RDS service operations"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(var.common_tags, {
    Name      = "${var.name_prefix}-rds-sg"
    Component = "database"
  })
}

resource "aws_db_subnet_group" "this" {
  name       = "${replace(var.name_prefix, "-", "")}-db-subnets"
  subnet_ids = var.private_subnet_ids

  tags = merge(var.common_tags, {
    Name      = "${var.name_prefix}-db-subnets"
    Component = "database"
  })
}

resource "aws_db_parameter_group" "this" {
  name        = "${replace(var.name_prefix, "-", "")}-dagster-pg"
  family      = "postgres16"
  description = "Parameter group for Dagster metadata PostgreSQL logging"

  parameter {
    name  = "log_statement"
    value = "all"
  }

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  tags = merge(var.common_tags, {
    Name      = "${var.name_prefix}-dagster-pg"
    Component = "database"
  })
}

resource "aws_iam_role" "enhanced_monitoring" {
  count = var.enable_enhanced_monitoring ? 1 : 0
  name  = "${var.name_prefix}-rds-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name      = "${var.name_prefix}-rds-monitoring"
    Component = "database"
  })
}

resource "aws_iam_role_policy_attachment" "enhanced_monitoring" {
  count      = var.enable_enhanced_monitoring ? 1 : 0
  role       = aws_iam_role.enhanced_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_db_instance" "this" {
  identifier                            = "${var.name_prefix}-dagster"
  engine                                = "postgres"
  engine_version                        = var.engine_version
  instance_class                        = var.db_instance_class
  allocated_storage                     = var.allocated_storage
  max_allocated_storage                 = var.max_allocated_storage
  storage_type                          = "gp3"
  storage_encrypted                     = true
  db_name                               = var.db_name
  username                              = var.db_username
  port                                  = 5432
  publicly_accessible                   = false
  multi_az                              = var.multi_az
  backup_retention_period               = 7
  backup_window                         = "03:00-04:00"
  maintenance_window                    = "Mon:04:00-Mon:05:00"
  auto_minor_version_upgrade            = true
  deletion_protection                   = false
  skip_final_snapshot                   = var.skip_final_snapshot
  apply_immediately                     = true
  copy_tags_to_snapshot                 = true
  db_subnet_group_name                  = aws_db_subnet_group.this.name
  vpc_security_group_ids                = [aws_security_group.this.id]
  manage_master_user_password           = true
  iam_database_authentication_enabled   = true
  enabled_cloudwatch_logs_exports       = ["postgresql", "upgrade"]
  parameter_group_name                  = aws_db_parameter_group.this.name
  performance_insights_enabled          = var.enable_performance_insights
  performance_insights_kms_key_id       = var.enable_performance_insights ? data.aws_kms_alias.rds.target_key_arn : null
  performance_insights_retention_period = var.enable_performance_insights ? 7 : null
  monitoring_interval                   = var.enable_enhanced_monitoring ? 60 : 0
  monitoring_role_arn                   = var.enable_enhanced_monitoring ? aws_iam_role.enhanced_monitoring[0].arn : null

  tags = merge(var.common_tags, {
    Name      = "${var.name_prefix}-dagster"
    Component = "database"
  })
}
