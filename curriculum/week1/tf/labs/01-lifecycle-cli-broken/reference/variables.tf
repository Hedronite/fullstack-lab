variable "region" {
  description = "AWS region for the log bucket."
  type        = string
  default     = "us-east-1"
}

variable "expire_after_days" {
  description = "Days after which objects under logs/ are deleted."
  type        = number
  default     = 30
}
