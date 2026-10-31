terraform {
  # Pinned to the lab image (hedronite/fullstack-lab-tf:1.10.5-aws) so grading is reproducible.
  required_version = "= 1.10.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 6.71.0" # the version mirrored offline in the lab image
    }
  }
}

provider "aws" {
  region = var.region
}
