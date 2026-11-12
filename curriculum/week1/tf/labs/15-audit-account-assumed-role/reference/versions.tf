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

# The edge service's own account. Credentials come from the run's environment.
provider "aws" {
  region = var.region
}

# The audit account: the run's own credentials assume a role there. No key for the audit
# account exists anywhere in configuration; the role's trust policy decides who may assume it.
provider "aws" {
  alias  = "audit"
  region = var.region

  assume_role {
    role_arn     = var.audit_role_arn
    session_name = "hx-lab15"
  }
}
