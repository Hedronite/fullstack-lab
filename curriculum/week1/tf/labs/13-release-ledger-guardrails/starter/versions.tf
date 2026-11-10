terraform {
  # TODO(task 3): this accepts Terraform 0.13 up to any future major release. Bound it to
  #               the 1.10 series with a pessimistic constraint (the lab image runs 1.10.5).
  required_version = ">= 0.13"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.71"
    }
  }
}

provider "aws" {
  region = var.region
}
