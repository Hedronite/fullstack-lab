terraform {
  # TODO(task 3): bound Terraform to the 1.10 series with a pessimistic constraint
  #               (the lab image runs 1.10.5) and the AWS provider to the 6.71 minor line
  #               or later 6.x with "~> 6.71". The lock file pins the exact build either way.
  required_version = ">= 0.13"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}
