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

provider "aws" {
  region = var.region

  # TODO(task 4): the provider is handed long-lived keys through two input variables (see
  #               variables.tf). Remove these two lines and the two variables. A run gets its
  #               credentials from its environment (or, in HCP Terraform, from dynamic
  #               provider credentials), never from configuration.
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}
