# =============================================================================
# Credit Card Fraud Detection  V5 - Centralized Configuration Module
# Author: Rodrigo Marins Piaba (Fanaticos4tech)
# E-mail: rodrigomarinsp@gmail.com
# Project: https://github.com/rodrigomarinsp/fsah-neural
# =============================================================================
# Centralized Configuration Module 
# Central point of the system
# =============================================================================

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "fraud-detection-prod-vpc"
    App  = "flask-cnn-app-py39"
    Type = "Real-Application"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "fraud-detection-prod-igw"
    App  = "flask-cnn-app-py39"
  }
}

# Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "fraud-detection-prod-public-subnet"
    App  = "flask-cnn-app-py39"
  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "fraud-detection-prod-public-rt"
    App  = "flask-cnn-app-py39"
  }
}

# Route Table Association
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security Group
resource "aws_security_group" "web" {
  name_prefix = "fraud-detection-prod-web-"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8502
    to_port     = 8502
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "fraud-detection-prod-web-sg"
    App  = "flask-cnn-app-py39"
  }
}

# Key Pair
resource "aws_key_pair" "main" {
  key_name   = "fraud-detection-prod-key"
  public_key = tls_private_key.main.public_key_openssh

  tags = {
    Name = "fraud-detection-prod-key"
    App  = "flask-cnn-app-py39"
  }
}

resource "tls_private_key" "main" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  content         = tls_private_key.main.private_key_pem
  filename        = "fraud-detection-prod-key.pem"
  file_permission = "0400"
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# EC2 Instance
resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.xlarge"
  key_name               = aws_key_pair.main.key_name
  vpc_security_group_ids = [aws_security_group.web.id]
  subnet_id              = aws_subnet.public.id

  user_data = base64encode(templatefile("fixed_user_data.sh", {
    app_name = "flask-cnn-app-py39"
  }))

  tags = {
    Name = "fraud-detection-prod-flask-cnn-app-py39"
    App  = "flask-cnn-app-py39"
    Type = "Real-Application"
  }
}

# Elastic IP
resource "aws_eip" "web" {
  instance = aws_instance.web.id
  domain   = "vpc"

  tags = {
    Name = "fraud-detection-prod-eip"
    App  = "flask-cnn-app-py39"
  }

  depends_on = [aws_internet_gateway.main]
}

# Outputs
output "instance_id" {
  value = aws_instance.web.id
}

output "public_ip" {
  value = aws_eip.web.public_ip
}

output "app_url" {
  value = "http://${aws_eip.web.public_ip}:8502"
}

output "ssh_command" {
  value = "ssh -i fraud-detection-prod-key.pem ec2-user@${aws_eip.web.public_ip}"
}
