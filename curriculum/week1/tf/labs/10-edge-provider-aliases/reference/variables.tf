variable "region" {
  description = "Primary region for the release-artifacts bucket."
  type        = string
  default     = "us-east-1"
}

variable "dr_region" {
  description = "Second region for the replica bucket."
  type        = string
  default     = "us-west-2"
}

variable "dr_role_arn" {
  description = "Deployer role the pipeline assumes for the second region."
  type        = string
  default     = "arn:aws:iam::123456789012:role/hx-lab10-edge-deployer"
}
