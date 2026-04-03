variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "hydrosat"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name for Terraform remote state."
  type        = string
}

variable "lock_table_name" {
  description = "DynamoDB table name for Terraform state locks."
  type        = string
  default     = "hydrosat-terraform-locks"
}

variable "extra_tags" {
  type    = map(string)
  default = {}
}

