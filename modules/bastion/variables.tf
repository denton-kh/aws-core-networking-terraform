variable "vpc_id" {
  description = "ID of the VPC where Bastion will be launched"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
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

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into Bastion (do not use 0.0.0.0/0 in production)"
  type        = string
  default     = "10.0.0.0/8"
}

variable "instance_type" {
  description = "EC2 instance type for Bastion"
  type        = string
  default     = "t3.micro"
}

variable "ami" {
  description = "AMI ID for Bastion EC2"
  type        = string
  default     = ""
}