variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "aws_profile" {
  type    = string
  default = "default"
}

variable "project" {
  type    = string
  default = "mlops-rag"
}

# Networking
variable "vpc_cidr" {
  type        = string
  default     = "10.20.0.0/16"
  description = "CIDR block for the VPC"
}
variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.20.1.0/24", "10.20.2.0/24"]
}
variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.20.3.0/24", "10.20.4.0/24"]
}

# RDS
variable "db_name" {
  type        = string
  default     = "ragdb"
  description = "Name of the RDS database"
}
variable "db_username" {
  type    = string
  default = "raguser"
}
variable "app_username" {
  type    = string
  default = "appuser"
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.medium"
}
variable "db_allocated_storage" {
  type    = number
  default = 50
}

# Dev-only: allow psql from your home IP (e.g. "X.X.X.X/32")
variable "allowed_cidr_home" {
  type = string
  default = "136.49.124.114/32"
}
