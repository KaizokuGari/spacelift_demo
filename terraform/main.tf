terraform {
  required_version = ">= 1.0"
}

provider "aws" {
  region = var.aws_region
  access_key="ASIA2IJHYD7YIX7IC2EJ" 
  secret_key="E0YCeLWiNRIWLuFKDbzWN2Pb1k0jTxBHhO3P43af"
  token="IQoJb3JpZ2luX2VjEFAaCXVzLXdlc3QtMiJHMEUCIDag837hZ+3/bAFhklEdEJtjFpla6sLT2MGuq9UFOYQiAiEAj/h9R26J9tghC+smwZOZ7gjffFUfeLiTGarbCFanG/wqowIIKRAAGgw3MDQ5OTQ4Nzc0MjQiDJX25lSvJ1H132SF7iqAAi9D/zPqy7ZzueBlRws4f4O6sqC1WcCr62M1LfUF8Xmflkszw22KVd3aQOVD0c7P+306RnnJOTX5dFbeJ9qy4K6lp7m5SgNK4lYhMVjroiiWBimSPQnXeZQW9NJxqklDVRm14OxgjaQhWZVXhgmGrJjEFaspYoGRmXeJI/WH6NGS69s19tALFKWWVsqtfvRULftx3wQKWV2Fdatsxt4FFT87pIQGdHVQbnuU8voCj1fbZs8DyCv8ZlMRm8D1/EdvNohx2dZWzORxrJfrirsHpuomX+MOIiYJr0rt+TgF7xmZ6bqBmn15ysIsA6OYCBo4rjZh661x5ZSL3SbIx49PJPww8Pr/wQY6nQFtPT6p4zFlT6VePJrd1Ne7bE5vPXF0OTGTpVvf0DONRdhiGsA3tZWEDyzXcg4WJZ/CfQY4V6OvcAXUza4FqENkr5krtASuVUqoC9lmqZdV6tAPHibT9LEPM6xjFRmnIdnDYNM9Q2trzwNYzmuDzBCb9/s6L4bTKovSst7QL9i1oWQgCSr97bHjG+gsP0vkJqgk4n4zUxzdYFKF9dNt"
}

# Generate SSH key pair
resource "tls_private_key" "demo_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Store private key in SSM Parameter Store
resource "aws_ssm_parameter" "private_key" {
  name        = "/ssh/demo-keypair/private"
  description = "Private SSH key for EC2 demo"
  type        = "SecureString"
  value       = tls_private_key.demo_key.private_key_pem

  tags = {
    environment = "demo"
  }
}

# Create AWS key pair using the public key
resource "aws_key_pair" "demo_keypair" {
  key_name   = "demo-keypair"
  public_key = tls_private_key.demo_key.public_key_openssh
}

# Create VPC
resource "aws_vpc" "demo_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "demo-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "demo_igw" {
  vpc_id = aws_vpc.demo_vpc.id

  tags = {
    Name = "demo-igw"
  }
}

# Route Table
resource "aws_route_table" "demo_rt" {
  vpc_id = aws_vpc.demo_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.demo_igw.id
  }

  tags = {
    Name = "demo-rt"
  }
}

# Subnet
resource "aws_subnet" "demo_subnet" {
  vpc_id                  = aws_vpc.demo_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "demo-subnet"
  }
}

# Route Table Association
resource "aws_route_table_association" "demo_rta" {
  subnet_id      = aws_subnet.demo_subnet.id
  route_table_id = aws_route_table.demo_rt.id
}

# Security Group
resource "aws_security_group" "demo_sg" {
  name        = "demo-sg"
  description = "Allow SSH and HTTP inbound traffic"
  vpc_id      = aws_vpc.demo_vpc.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
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
    Name = "demo-sg"
  }
}

# EC2 Instance
resource "aws_instance" "demo_instance" {
  ami                    = "ami-0c02fb55956c7d316" // Replace with a valid AMI ID for your region
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.demo_subnet.id
  key_name               = aws_key_pair.demo_keypair.key_name
  vpc_security_group_ids = [aws_security_group.demo_sg.id]

  user_data = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y python3 python3-pip python3-venv
  EOF

  tags = {
    Name = "demo-instance"
  }
}

# Outputs
output "instance_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.demo_instance.public_ip
}
