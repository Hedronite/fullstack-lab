terraform {
  required_version = "~> 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.71"
    }
  }

  # Task 4: partial configuration. bucket and key come from prod.s3.tfbackend at init time
  # (terraform init -backend-config=prod.s3.tfbackend); use_lockfile locks the state in S3.
  backend "s3" {
    region       = "us-east-1"
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region
}
