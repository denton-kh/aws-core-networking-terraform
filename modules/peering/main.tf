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
# 1. VPC Peering Connection
# =========================================================================
resource "aws_vpc_peering_connection" "peering" {
  vpc_id      = var.vpc_id
  peer_vpc_id = var.peer_vpc_id
  auto_accept = true

  tags = merge(
    {
      Name        = "${var.environment}-peering"
      Environment = var.environment
    },
    var.tags
  )
}

# =========================================================================
# 2. Add route to peer VPC in each local route table
# =========================================================================
resource "aws_route" "peering_route" {
  count                     = length(var.route_table_ids)
  route_table_id            = var.route_table_ids[count.index]
  destination_cidr_block    = var.peer_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peering.id
}