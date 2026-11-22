variable "vpc_id" {
  description = "ID of the local VPC (Requester)"
  type        = string
}

variable "peer_vpc_id" {
  description = "ID of the peer VPC (Accepter)"
  type        = string
}

variable "peer_cidr_block" {
  description = "CIDR block of the peer VPC"
  type        = string
}

variable "route_table_ids" {
  description = "List of local route table IDs to add peering routes"
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