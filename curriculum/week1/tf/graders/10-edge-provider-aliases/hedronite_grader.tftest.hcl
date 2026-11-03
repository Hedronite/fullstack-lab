# Hedronite lab 10 (edge provider aliases) grader.
# Staged as tests/hedronite_grader.tftest.hcl by curriculum/week1/tf/stage.sh.
# Offline by construction: mock_provider means no cloud credentials, no cloud calls, no cost.
# Needs Terraform >= 1.7 for mock_provider; the lab pins 1.10.5 (the lab image).
#
# How it sees the provider: each mock_provider gives aws_s3_bucket a different computed
# `arn`, so the arn a bucket ends up with tells which provider configuration managed it.
# Version constraints and provider credentials are not visible to a plan; check.sh
# checks those two (tasks 2 and 3) statically.

mock_provider "aws" {
  mock_resource "aws_s3_bucket" {
    defaults = {
      arn = "arn:aws:s3:::hx-mock-primary"
    }
  }
}

mock_provider "aws" {
  alias = "dr"

  mock_resource "aws_s3_bucket" {
    defaults = {
      arn = "arn:aws:s3:::hx-mock-dr"
    }
  }
}

run "buckets_land_in_the_right_region" {
  # apply against the mock providers (offline, nothing real is created): computed
  # attributes such as arn are unknown at plan time and only filled in after a mock apply.
  command = apply

  assert {
    condition     = aws_s3_bucket.releases.arn == "arn:aws:s3:::hx-mock-primary"
    error_message = "The primary release bucket must stay on the default aws provider."
  }

  assert {
    condition     = aws_s3_bucket.releases_dr.arn == "arn:aws:s3:::hx-mock-dr"
    error_message = "Task 1: the replica bucket is managed by the default provider. Add provider = aws.dr so it is created through the aliased provider (second region)."
  }
}
