variable "region" {
  description = "Region for the edge service database."
  type        = string
  default     = "us-east-1"
}

# TODO(task 1): this password is a secret. As written, plan and apply print it, and it has a
#               default, so a run that forgets to supply it quietly uses the one in the code.
variable "db_password" {
  description = "Master password for the edge service database."
  type        = string
  default     = "hx-lab12-change-me"
}

# TODO(task 4): remove both credential variables (and their use in the provider block).
variable "aws_access_key" {
  type    = string
  default = "hx-lab12-not-a-real-key"
}

variable "aws_secret_key" {
  type    = string
  default = "hx-lab12-not-a-real-secret"
}
