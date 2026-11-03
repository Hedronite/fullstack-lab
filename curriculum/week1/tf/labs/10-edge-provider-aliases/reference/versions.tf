terraform {
  # Pinned to the lab image (hedronite/fullstack-lab-tf:1.10.5-aws) so grading is reproducible.
  required_version = "= 1.10.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.71" # 6.71 and later 6.x, never 7.0; the lock file records 6.71.0
    }
  }
}

provider "aws" {
  region = var.region
}

provider "aws" {
  alias  = "dr"
  region = var.dr_region

  # No keys in configuration: base credentials come from the environment or shared config
  # (AWS_PROFILE, AWS_ACCESS_KEY_ID in the pipeline, an instance role), and this block
  # switches to the deployer role for the second region.
  assume_role {
    role_arn     = var.dr_role_arn
    session_name = "hx-lab10-terraform"
  }
}
