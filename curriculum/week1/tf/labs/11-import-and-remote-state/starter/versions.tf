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

    # TODO(task 3): state locking goes through a DynamoDB table today. Terraform 1.10 can lock
    #               with a lock file kept next to the state object. Switch to that and drop
    #               the table.
    dynamodb_table = "hx-lab11-state-locks"
  }
}

provider "aws" {
  region = var.region
}
