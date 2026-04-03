data "aws_kms_alias" "s3" {
  count = var.enable_kms_hardening ? 1 : 0
  name  = "alias/aws/s3"
}

resource "aws_s3_bucket" "data_lake" {
  bucket = "${var.name_prefix}-data-lake"

  tags = merge(var.common_tags, {
    Name      = "${var.name_prefix}-data-lake"
    Component = "platform"
  })
}

resource "aws_s3_bucket_versioning" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.enable_kms_hardening ? "aws:kms" : "AES256"
      kms_master_key_id = var.enable_kms_hardening ? data.aws_kms_alias.s3[0].target_key_arn : null
    }
    bucket_key_enabled = var.enable_kms_hardening
  }
}

resource "aws_s3_bucket_public_access_block" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  rule {
    id     = "transition-and-cleanup-noncurrent"
    status = "Enabled"

    filter {
      prefix = ""
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

resource "aws_iam_role" "external_secrets_service_account" {
  name = "${var.name_prefix}-external-secrets-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(var.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:${var.external_secrets_namespace}:${var.external_secrets_service_account_name}"
            "${replace(var.oidc_provider_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name      = "${var.name_prefix}-external-secrets-irsa"
    Component = "platform"
  })
}

resource "aws_iam_role" "dagster_service_account" {
  name = "${var.name_prefix}-dagster-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(var.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:${var.dagster_namespace}:${var.dagster_service_account_name}"
            "${replace(var.oidc_provider_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name      = "${var.name_prefix}-dagster-irsa"
    Component = "platform"
  })
}

resource "aws_iam_role_policy" "dagster_data_lake_access" {
  name = "${var.name_prefix}-dagster-data-lake-access"
  role = aws_iam_role.dagster_service_account.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation",
        ]
        Resource = aws_s3_bucket.data_lake.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
        ]
        Resource = "${aws_s3_bucket.data_lake.arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "external_secrets_read_secrets" {
  name = "${var.name_prefix}-external-secrets-read-secrets"
  role = aws_iam_role.external_secrets_service_account.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:ListSecretVersionIds",
        ]
        Resource = var.external_secrets_secret_arns
      }
    ]
  })
}
