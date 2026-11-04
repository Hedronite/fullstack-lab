terraform {
  # Pinned to the lab image (hedronite/fullstack-lab-tf:1.10.5-aws) so grading is reproducible.
  required_version = "= 1.10.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.71"
    }
  }

  backend "s3" {
    bucket = "hx-lab11-state"
    key    = "edge/terraform.tfstate"
    region = "us-east-1"

    # Native locking: a lock file next to the state object, no DynamoDB table.
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region
}
