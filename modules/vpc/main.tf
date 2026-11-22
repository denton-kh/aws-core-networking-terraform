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
# 1. VPC
# =========================================================================
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    {
      Name        = "${var.environment}-main-vpc"
      Environment = var.environment
    },
  )
}

# =========================================================================
# 2. Internet Gateway (IGW)
# =========================================================================
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    {
      Name        = "${var.environment}-igw"
      Environment = var.environment
    },
    var.tags
  )
}

# =========================================================================
# 3. Public Subnets (one per AZ)
# =========================================================================
resource "aws_subnet" "public" {
  count                   = length(var.azs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = false

  tags = merge(
    {
      Name        = "${var.environment}-public-subnet-${count.index + 1}"
      Environment = var.environment
      Tier        = "public"
    },
    var.tags
  )
}

# =========================================================================
# 4. Private Subnets (one per AZ)
# =========================================================================
resource "aws_subnet" "private" {
  count                   = length(var.azs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = false

  tags = merge(
    {
      Name        = "${var.environment}-private-subnet-${count.index + 1}"
      Environment = var.environment
      Tier        = "private"
    },
    var.tags
  )
}

# =========================================================================
# 5. Elastic IP for NAT Gateway (one per AZ)
# =========================================================================
resource "aws_eip" "nat" {
  count  = length(var.azs)
  domain = "vpc"

  tags = merge(
    {
      Name        = "${var.environment}-nat-eip-${count.index + 1}"
      Environment = var.environment
    },
    var.tags
  )
}

# =========================================================================
# 6. NAT Gateway (one per public subnet)
# =========================================================================
resource "aws_nat_gateway" "nat" {
  count         = length(var.azs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(
    {
      Name        = "${var.environment}-nat-gateway-${count.index + 1}"
      Environment = var.environment
    },
    var.tags
  )
}

# =========================================================================
# 7. Public Route Table (default route via IGW)
# =========================================================================
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = merge(
    {
      Name        = "${var.environment}-public-rt"
      Environment = var.environment
    },
    var.tags
  )
}

# Associate all public subnets with this route table
resource "aws_route_table_association" "public" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# =========================================================================
# 8. Private Route Tables (one per AZ, route via NAT Gateway)
# =========================================================================
resource "aws_route_table" "private" {
  count  = length(var.azs)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index].id
  }

  tags = merge(
    {
      Name        = "${var.environment}-private-rt-${count.index + 1}"
      Environment = var.environment
    },
    var.tags
  )
}

# Associate private subnets with their own route tables
resource "aws_route_table_association" "private" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# =========================================================================
# 9. VPC Endpoint for S3 (Gateway type)
# =========================================================================
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"

  # Attach to private route tables so private subnets can reach S3
  # without using NAT Gateway
  route_table_ids = aws_route_table.private[*].id

  tags = merge(
    {
      Name        = "${var.environment}-vpce-s3"
      Environment = var.environment
    },
    var.tags
  )
}

# =========================================================================
# 10. VPC Endpoint for DynamoDB (Gateway type)
# =========================================================================
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.region}.dynamodb"
  vpc_endpoint_type = "Gateway"

  # Attach to private route tables so private subnets can reach DynamoDB
  # without using NAT Gateway
  route_table_ids = aws_route_table.private[*].id

  tags = merge(
    {
      Name        = "${var.environment}-vpce-dynamodb"
      Environment = var.environment
    },
    var.tags
  )
}