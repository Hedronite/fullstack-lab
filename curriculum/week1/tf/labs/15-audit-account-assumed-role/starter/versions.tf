terraform {
  # Pinned to the lab image (hedronite/fullstack-lab-tf:1.10.5-aws) so grading is reproducible.
  required_version = "= 1.10.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.71"
    }
  }
}

# The edge service's own account.
provider "aws" {
  region = var.region
}

# The separate audit account, as the on-call engineer found it.
provider "aws" {
  alias  = "audit"
  region = var.region

  # TODO(task 3): the audit account is reached with a long-lived IAM user key that lives in
  #               configuration. Replace these two lines with an assume_role block (role_arn =
  #               var.audit_role_arn), and delete the two variables that feed them.
  access_key = var.audit_access_key
  secret_key = var.audit_secret_key
}
