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

# TODO(task 2): this key lets a caller write to the audit sink. As written, plan and apply
#               print it, and it has a default, so a run that forgets to pass one silently uses
#               the one in the code.
variable "sink_api_key" {
  description = "API key for the audit sink."
  type        = string
  default     = "hx-lab15-change-me"
}

# TODO(task 3): remove both variables (and their use in versions.tf).
variable "audit_access_key" {
  type    = string
  default = "hx-lab15-not-a-real-key"
}

variable "audit_secret_key" {
  type    = string
  default = "hx-lab15-not-a-real-secret"
}
