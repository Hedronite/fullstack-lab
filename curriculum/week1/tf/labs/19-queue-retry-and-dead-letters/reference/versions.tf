terraform {
  required_version = "~> 1.10" # 1.10.x and later 1.x minors, never 2.0; the lab image runs 1.10.5

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
