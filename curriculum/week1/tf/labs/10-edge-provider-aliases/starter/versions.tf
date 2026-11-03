terraform {
  # Pinned to the lab image (hedronite/fullstack-lab-tf:1.10.5-aws) so grading is reproducible.
  required_version = "= 1.10.5"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # TODO(task 2): this constraint accepts every release from 5.0 on, including a
      #               future 7.x. Bound it to the 6.71 series.
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

provider "aws" {
  alias  = "dr"
  region = var.dr_region

  # TODO(task 3): long-lived keys do not belong in configuration. Remove both lines and
  #               authenticate through the environment plus an assume_role block that
  #               names var.dr_role_arn.
  access_key = "hx-lab10-not-a-real-key"
  secret_key = "hx-lab10-not-a-real-secret"
}
