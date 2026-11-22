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
# 1. Security Group for Application Load Balancer
# =========================================================================
resource "aws_security_group" "alb" {
  name        = "${var.environment}-alb-sg"
  description = "Allow HTTP to ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow outbound HTTPS"
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
      Name        = "${var.environment}-alb-sg"
      Environment = var.environment
    },
    var.tags
  )
}

# =========================================================================
# 2. Security Group for EC2 Instances
# =========================================================================
resource "aws_security_group" "ec2" {
  name        = "${var.environment}-ec2-sg"
  description = "Allow HTTP from ALB and SSH from Bastion"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # SSH from Bastion (only if bastion_sg_id is provided)
  dynamic "ingress" {
    for_each = var.bastion_sg_id != "" ? [1] : []
    content {
      from_port       = 22
      to_port         = 22
      protocol        = "tcp"
      security_groups = [var.bastion_sg_id]
    }
  }

  egress {
    description = "Allow outbound HTTPS"
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
      Name        = "${var.environment}-ec2-sg"
      Environment = var.environment
    },
    var.tags
  )
}

# =========================================================================
# 3. Target Group for ALB
# =========================================================================
resource "aws_lb_target_group" "web" {
  name     = "${var.environment}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path = "/"
  }

  tags = merge(
    {
      Name        = "${var.environment}-tg"
      Environment = var.environment
    },
    var.tags
  )
}

# =========================================================================
# 4. Application Load Balancer
# =========================================================================
resource "aws_lb" "web" {
  name               = "${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  drop_invalid_header_fields = true

  tags = merge(
    {
      Name        = "${var.environment}-alb"
      Environment = var.environment
    },
    var.tags
  )
}

# =========================================================================
# 5. ALB Listener
# =========================================================================
resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.web.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = var.alb_ssl_certificate_arn

  default_action {
    target_group_arn = aws_lb_target_group.web.arn
    type             = "forward"
  }
}

# =========================================================================
# 6. Launch Template for Auto Scaling Group
# =========================================================================
resource "aws_launch_template" "web" {
  name_prefix   = "${var.environment}-lt-"
  image_id      = var.ami
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.ec2.id]

  metadata_options {
    http_tokens = "required"
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(
      {
        Name        = "${var.environment}-web"
        Environment = var.environment
      },
      var.tags
    )
  }

  # Encrypted root EBS volume
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }
}

# =========================================================================
# 7. Auto Scaling Group
# =========================================================================
resource "aws_autoscaling_group" "web" {
  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  vpc_zone_identifier = var.private_subnet_ids

  target_group_arns = [aws_lb_target_group.web.arn]

  health_check_type = "ELB"

  min_size         = var.capacity_min
  max_size         = var.capacity_max
  desired_capacity = var.capacity_desired

  tag {
    key                 = "Name"
    value               = "${var.environment}-asg"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }
}