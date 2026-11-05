terraform {
  # Pinned to the lab image (hedronite/fullstack-lab-tf:1.10.5-aws) so grading is reproducible.
  required_version = "= 1.10.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.71"
    }
  }
}

# No credentials here. A run authenticates from its environment (AWS_PROFILE, AWS_ACCESS_KEY_ID
# and friends, or an instance role); in HCP Terraform, dynamic provider credentials are set as
# workspace variables (TFC_AWS_PROVIDER_AUTH, TFC_AWS_RUN_ROLE_ARN), so nothing secret is in
# the repository.
provider "aws" {
  region = var.region
}
