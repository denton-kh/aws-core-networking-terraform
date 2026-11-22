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

# =========================================================================
# 1. Main Production VPC
# =========================================================================
module "main_vpc" {
  source = "../../modules/vpc"

  environment = "dev"
  vpc_cidr    = "10.0.0.0/16"

  azs = ["us-east-1a", "us-east-1b"]

  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24"]
}

# =========================================================================
# 2. Internal / Analytics VPC (for peering demo)
# =========================================================================
module "internal_vpc" {
  source = "../../modules/vpc"

  environment = "dev"
  vpc_cidr    = "10.1.0.0/16"

  azs = ["us-east-1a", "us-east-1b"]

  public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24"]
  private_subnet_cidrs = ["10.1.10.0/24", "10.1.20.0/24"]
}

# =========================================================================
# 3. Bastion Host
# =========================================================================
module "bastion" {
  source = "../../modules/bastion"

  vpc_id            = module.main_vpc.vpc_id
  public_subnet_ids = module.main_vpc.public_subnet_ids
  environment       = "dev"
}

# =========================================================================
# 4. Compute (ALB + ASG + EC2)
# =========================================================================
module "compute" {
  source = "../../modules/compute"

  vpc_id             = module.main_vpc.vpc_id
  public_subnet_ids  = module.main_vpc.public_subnet_ids
  private_subnet_ids = module.main_vpc.private_subnet_ids
  bastion_sg_id      = module.bastion.bastion_security_group_id
  environment        = "dev"

  # TODO: insert a valid AMI ID for us-east-1 (e.g. Amazon Linux 2)
  ami = ""

  # TODO: insert a valid ACM certificate ARN for HTTPS listener
  alb_ssl_certificate_arn = ""
}

# =========================================================================
# 5. VPC Peering between Main and Internal VPC
# =========================================================================
module "peering" {
  source = "../../modules/peering"

  vpc_id          = module.main_vpc.vpc_id
  peer_vpc_id     = module.internal_vpc.vpc_id
  peer_cidr_block = "10.1.0.0/16"
  route_table_ids = module.main_vpc.private_route_table_ids
  environment     = "dev"
}