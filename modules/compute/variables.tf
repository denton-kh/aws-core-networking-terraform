variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for ALB"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for EC2"
  type        = list(string)
}

variable "bastion_sg_id" {
  description = "Security Group ID of Bastion Host (for SSH access)"
  type        = string
  default     = ""
}

variable "environment" {
  description = "Environment name for tagging"
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "Extra tags"
  type        = map(string)
  default     = {}
}

variable "instance_type" {
  description = "EC2 instance type for Auto Scaling Group"
  type        = string
  default     = "t3.micro"
}

variable "ami" {
  description = "AMI ID for EC2 instances"
  type        = string
  default     = ""
}

variable "capacity_min" {
  description = "Minimum ASG capacity"
  type        = number
  default     = 1
}

variable "capacity_max" {
  description = "Maximum ASG capacity"
  type        = number
  default     = 3
}

variable "capacity_desired" {
  description = "Desired ASG capacity"
  type        = number
  default     = 2
}

variable "alb_ssl_certificate_arn" {
  description = "ARN of SSL certificate for ALB HTTPS listener"
  type        = string
  default     = ""
}