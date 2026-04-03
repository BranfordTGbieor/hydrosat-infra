output "external_secrets_service_account_role_arn" {
  value = aws_iam_role.external_secrets_service_account.arn
}

output "dagster_service_account_role_arn" {
  value = aws_iam_role.dagster_service_account.arn
}

output "data_lake_bucket_name" {
  value = aws_s3_bucket.data_lake.bucket
}

output "data_lake_bucket_arn" {
  value = aws_s3_bucket.data_lake.arn
}
