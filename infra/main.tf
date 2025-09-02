locals {
  name = var.project
  tags = {
    Project = var.project
    Env     = "dev"
    Owner   = "you"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "random_id" "suffix" {
  byte_length = 3
}

# ---------------- VPC ----------------
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = merge(local.tags, { Name = "${local.name}-vpc" })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Name = "${local.name}-igw" })
}

# Public subnets in two AZs
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[0]
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags                    = merge(local.tags, { Name = "${local.name}-public-a" })
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[1]
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true
  tags                    = merge(local.tags, { Name = "${local.name}-public-b" })
}

# Private subnets for RDS
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[0]
  availability_zone = data.aws_availability_zones.available.names[0]
  tags              = merge(local.tags, { Name = "${local.name}-private-a" })
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[1]
  availability_zone = data.aws_availability_zones.available.names[1]
  tags              = merge(local.tags, { Name = "${local.name}-private-b" })
}

# Public routing
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Name = "${local.name}-public-rt" })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.public.id
}



# ---------------- S3 bucket ----------------
resource "aws_s3_bucket" "docs" {
  bucket = "${local.name}-docs-${random_id.suffix.hex}"
  tags   = local.tags
}

resource "aws_s3_bucket_public_access_block" "docs_block" {
  bucket                  = aws_s3_bucket.docs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------------- Security group for RDS ----------------
resource "aws_security_group" "rds_sg" {
  name        = "${local.name}-rds-sg"
  description = "Allow Postgres"
  vpc_id      = aws_vpc.this.id
  tags        = local.tags



  # Allow from inside VPC (for future services like Lambda/EKS)
  ingress {
    description = "VPC internal"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.this.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------------- DB subnet group ----------------
resource "aws_db_subnet_group" "this" {
  name       = "${local.name}-db-subnets"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  tags       = local.tags
}

# Optional parameter group (default works fine for pgvector)
resource "aws_db_parameter_group" "this" {
  name        = "${local.name}-pg"
  family      = "postgres17"
  description = "Params for Postgres 17"
  tags        = local.tags
}

# ---------------- RDS PostgreSQL ----------------
resource "aws_db_instance" "postgres" {
  identifier              = "${local.name}-pg"
  engine                  = "postgres"
  engine_version          = "17.5"
  instance_class          = var.db_instance_class
  allocated_storage       = var.db_allocated_storage
  db_subnet_group_name    = aws_db_subnet_group.this.name
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  publicly_accessible     = false
  multi_az                = false
  username                = var.db_username
  password                = data.aws_secretsmanager_secret_version.db_password.secret_string
  db_name                 = var.db_name
  backup_retention_period = 1
  skip_final_snapshot     = true
  parameter_group_name    = aws_db_parameter_group.this.name
  deletion_protection     = false
  storage_encrypted       = true
  tags                    = local.tags
}



# -----------------------------
# IAM Role for EC2 (SSM access)
# -----------------------------
resource "aws_iam_role" "ec2_ssm_role" {
  name = "${local.name}-ec2-ssm-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_ssm_core" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_ssm_profile" {
  name = "${local.name}-ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm_role.name
}

# -----------------------------
# Security Group for EC2
# -----------------------------
resource "aws_security_group" "ec2_private_sg" {
  name        = "${local.name}-ec2-private-sg"
  description = "EC2 private instance SG (SSM only, no inbound needed)"
  vpc_id      = aws_vpc.this.id
  tags        = local.tags

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# -----------------------------
# Private EC2 instance
# -----------------------------
resource "aws_instance" "ssm_ec2" {
  ami                    = data.aws_ami.amazon_linux2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_a.id
  vpc_security_group_ids = [aws_security_group.ec2_private_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm_profile.name

  associate_public_ip_address = true

  tags = merge(local.tags, {
    Name = "${local.name}-ssm-ec2"
  })

user_data = <<-EOF
    #!/bin/bash
    set -eux

    # Update system
    sudo yum update -y

    # Install PostgreSQL client
    sudo yum install -y git python3-pip postgresql17 jq unzip wget tar postgresql17-contrib
    python3 -m pip install boto3 psycopg2-binary openai langchain pypdf pandas tiktoken dotenv

    # Verify installation
    psql --version
  EOF
}

# -----------------------------
# AMI Lookup (Amazon Linux 2023)
# -----------------------------
data "aws_ami" "amazon_linux2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

