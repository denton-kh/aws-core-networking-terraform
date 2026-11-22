terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# =========================================================================
# 1. Security Group for Bastion Host
# =========================================================================
resource "aws_security_group" "bastion" {
  name        = "${var.environment}-bastion-sg"
  description = "Allow SSH to Bastion Host"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    description = "Allow outbound HTTPS and DNS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow outbound HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow outbound DNS"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    {
      Name        = "${var.environment}-bastion-sg"
      Environment = var.environment
    },
    var.tags
  )
}

# =========================================================================
# 2. Elastic IP for Bastion
# =========================================================================
resource "aws_eip" "bastion" {
  domain = "vpc"

  tags = merge(
    {
      Name        = "${var.environment}-bastion-eip"
      Environment = var.environment
    },
    var.tags
  )
}

# =========================================================================
# 3. Bastion EC2 Instance
# =========================================================================
resource "aws_instance" "bastion" {
  ami                         = var.ami
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_ids[0]
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.bastion.id]

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = merge(
    {
      Name        = "${var.environment}-bastion"
      Environment = var.environment
    },
    var.tags
  )
}

# =========================================================================
# 4. Associate Elastic IP with Bastion instance
# =========================================================================
resource "aws_eip_association" "bastion" {
  instance_id   = aws_instance.bastion.id
  allocation_id = aws_eip.bastion.id
}