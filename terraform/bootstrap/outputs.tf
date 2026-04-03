output "state_bucket_name" {
  value = aws_s3_bucket.terraform_state.bucket
}

output "lock_table_name" {
  value = aws_dynamodb_table.terraform_locks.name
}

output "backend_config_snippet" {
  value = <<-EOT
    bucket         = "${aws_s3_bucket.terraform_state.bucket}"
    dynamodb_table = "${aws_dynamodb_table.terraform_locks.name}"
    region         = "${var.aws_region}"
    key            = "platform/terraform.tfstate"
    encrypt        = true
  EOT
}

