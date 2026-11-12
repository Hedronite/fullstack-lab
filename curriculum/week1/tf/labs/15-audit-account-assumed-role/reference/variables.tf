variable "region" {
  description = "Region for the edge service and the audit account."
  type        = string
  default     = "us-east-1"
}

variable "audit_role_arn" {
  description = "Role in the audit account that the pipeline is allowed to assume."
  type        = string
  default     = "arn:aws:iam::222222222222:role/hx-lab15-audit-writer"
}

variable "sink_api_key" {
  description = "API key for the audit sink."
  type        = string
  sensitive   = true
}
