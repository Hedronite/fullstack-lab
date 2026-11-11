terraform {
  required_version = "~> 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.71"
    }
  }

  # TODO(task 4): the state bucket and key are typed into this block, so every environment
  #               shares them, and nothing locks the state while a run is in progress.
  backend "s3" {
    bucket = "hx-lab14-state-prod"
    key    = "ledger/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.region
}
