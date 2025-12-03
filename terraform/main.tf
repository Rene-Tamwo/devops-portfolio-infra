terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Génération de la clé SSH
resource "tls_private_key" "kubernetes" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "kubernetes" {
  key_name   = var.key_name
  public_key = tls_private_key.kubernetes.public_key_openssh
}

# VPC et Networking
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.cluster_name}-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"

  tags = {
    Name = "${var.cluster_name}-public-subnet"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.cluster_name}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.cluster_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security Group pour les instances Kubernetes
resource "aws_security_group" "kubernetes" {
  name        = "${var.cluster_name}-sg"
  description = "Security group for Kubernetes cluster"
  vpc_id      = aws_vpc.main.id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Kubernetes API Server
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # etcd client API
  ingress {
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Kubelet API
  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # NodePort Services
  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All traffic between nodes
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  # Egress - tout sortant autorisé
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-sg"
  }
}

# Instance Master Kubernetes
resource "aws_instance" "master" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.kubernetes.key_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.kubernetes.id]

  root_block_device {
    volume_size = 20
    volume_type = "gp2"
  }

  user_data = file("${path.module}/scripts/master-setup.sh")

  tags = {
    Name = "${var.cluster_name}-master"
    Role = "master"
  }

  depends_on = [aws_internet_gateway.main]
}

# Instances Worker Kubernetes
resource "aws_instance" "workers" {
  count = var.node_count

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.kubernetes.key_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.kubernetes.id]

  root_block_device {
    volume_size = 20
    volume_type = "gp2"
  }

  user_data = templatefile("${path.module}/scripts/worker-setup.sh", {
    master_ip = aws_instance.master.private_ip
  })

  tags = {
    Name = "${var.cluster_name}-worker-${count.index + 1}"
    Role = "worker"
  }

  depends_on = [aws_instance.master]
}

# Data source pour l'AMI Ubuntu
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

