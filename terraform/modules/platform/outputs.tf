output "ecr_repository_url" {
  value = aws_ecr_repository.dagster.repository_url
}

output "external_secrets_service_account_role_arn" {
  value = aws_iam_role.external_secrets_service_account.arn
}
