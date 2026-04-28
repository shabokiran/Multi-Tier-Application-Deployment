terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Create VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = { Name = "devops-vpc" }
}

# Create Subnet
resource "aws_subnet" "main" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags = { Name = "devops-subnet" }
}

# Create Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "devops-igw" }
}

# Create Route Table
resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = { Name = "devops-rt" }
}

# Associate Route Table with Subnet
resource "aws_route_table_association" "main" {
  subnet_id = aws_subnet.main.id
  route_table_id = aws_route_table.main.id
}

# Security Group
resource "aws_security_group" "k8s" {
  name = "k8s-security-group"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH"
  }

  ingress {
    from_port = 6443
    to_port = 6443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "K8s API"
  }

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP"
  }

  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS"
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "k8s-sg" }
}

# EC2 Instance
resource "aws_instance" "k8s_server" {
  ami = data.aws_ami.ubuntu.id
  instance_type = "t3.medium"
  subnet_id = aws_subnet.main.id
  vpc_security_group_ids = [aws_security_group.k8s.id]
  key_name = var.key_name

  user_data = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y docker.io
    snap install microk8s --classic
    microk8s enable dns storage ingress
    EOF

  tags = { Name = "k8s-server" }
}

# Elastic IP
resource "aws_eip" "k8s" {
  instance = aws_instance.k8s_server.id
  domain = "vpc"
  tags = { Name = "k8s-eip" }
}

# Data source for Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"]
}

output "public_ip" {
  value = aws_eip.k8s.public_ip
  description = "EC2 Public IP"
}

output "ssh_command" {
  value = "ssh -i ${var.key_name}.pem ubuntu@${aws_eip.k8s.public_ip}"
}
