variable "region" {
  description = "Region for the edge service database."
  type        = string
  default     = "us-east-1"
}

# Sensitive, and no default: the value comes from TF_VAR_db_password, a secrets manager, or an
# HCP Terraform sensitive workspace variable, never from the code.
variable "db_password" {
  description = "Master password for the edge service database."
  type        = string
  sensitive   = true
}
