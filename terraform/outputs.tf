output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "aws_region" {
  description = "AWS region for CLI and Helm commands."
  value       = var.aws_region
}

output "container_repository_url" {
  description = "Optional platform-managed container repository URL."
  value       = module.platform.ecr_repository_url
}

output "ecr_repository_url" {
  description = "Legacy output name for the optional platform-managed ECR repository URL."
  value       = module.platform.ecr_repository_url
}

output "external_secrets_service_account_role_arn" {
  description = "IAM role ARN to annotate on the External Secrets Operator service account."
  value       = module.platform.external_secrets_service_account_role_arn
}

output "rds_address" {
  description = "RDS endpoint hostname for Dagster metadata storage."
  value       = module.rds.address
}

output "rds_port" {
  description = "RDS port for Dagster metadata storage."
  value       = module.rds.port
}

output "rds_database_name" {
  description = "RDS database name for Dagster metadata."
  value       = module.rds.db_name
}

output "rds_username" {
  description = "RDS username for Dagster metadata."
  value       = module.rds.username
}

output "rds_master_secret_arn" {
  description = "Secrets Manager ARN containing the RDS master password."
  value       = module.rds.master_user_secret_arn
}

output "kubectl_config_command" {
  description = "Command to refresh local kubeconfig for the new cluster."
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "cluster_endpoint_private_access" {
  description = "Whether the EKS API endpoint is reachable from inside the VPC."
  value       = var.cluster_endpoint_private_access
}

output "cluster_endpoint_public_access" {
  description = "Whether the EKS API endpoint is reachable from the public internet."
  value       = var.cluster_endpoint_public_access
}
