variable "region" {
  description = "AWS region for the audit ledger and its edge security group."
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "VPC that the edge security group belongs to."
  type        = string
  default     = "vpc-0hedronite0lab01"
}
