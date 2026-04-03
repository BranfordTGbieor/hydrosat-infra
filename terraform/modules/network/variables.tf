variable "name_prefix" {
  type = string
}

variable "enable_kms_hardening" {
  type = bool
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "private_subnet_cidrs" {
  type = list(string)
}

variable "public_subnet_azs" {
  type = list(string)
}

variable "private_subnet_azs" {
  type = list(string)
}

variable "eks_cluster_name" {
  type = string
}

variable "common_tags" {
  type = map(string)
}
