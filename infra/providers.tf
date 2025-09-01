terraform {
required_providers {
  aws = {
    source  = "hashicorp/aws"
    version = "~> 5.0"
  }
  postgresql = {
    source  = "cyrilgdn/postgresql"
    
  }
  random = {
    source  = "hashicorp/random"
    version = "~> 3.0"
  }
  }
  required_version = ">= 1.6.0"
}
provider "postgresql" {
  host            = aws_db_instance.postgres.address
  port            = 5432
  database        = var.db_name
  username        = var.db_username
  password        = data.aws_secretsmanager_secret_version.db_password.secret_string
  sslmode = "require"   
}