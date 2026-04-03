output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = [for idx in range(length(var.public_subnet_cidrs)) : aws_subnet.public[tostring(idx)].id]
}

output "private_subnet_ids" {
  value = [for idx in range(length(var.private_subnet_cidrs)) : aws_subnet.private[tostring(idx)].id]
}

