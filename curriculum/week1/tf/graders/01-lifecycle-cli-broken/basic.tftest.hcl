# Lab 01 — Lifecycle and CLI  ·  grader
# Staged next to its upstream lab by curriculum/week1/tf/stage.sh.
# Run with: terraform init && terraform test
#
# Offline by construction: mock_provider means NO AWS credentials, NO network, NO cost.
# Requires Terraform >= 1.7 for mock_provider. The lab's versions.tf allows >= 1.6 —
# on 1.6 exactly, this file will not parse. Both lab-image versions (1.9.8, 1.10.5) are fine.

mock_provider "aws" {}

run "bucket_name_was_actually_replaced" {
  command = plan

  assert {
    condition     = aws_s3_bucket.logs.bucket != "REPLACE-ME-WITH-A-UNIQUE-BUCKET-NAME"
    error_message = "The placeholder bucket name is still in main.tf. Task 2 asks you to replace it with a globally unique name."
  }
}

run "bucket_name_is_a_legal_s3_name" {
  command = plan

  assert {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", aws_s3_bucket.logs.bucket))
    error_message = "Bucket name must be 3-63 chars, lowercase alphanumeric plus dots and hyphens, and must start and end alphanumeric."
  }

  assert {
    condition     = !can(regex("[A-Z_]", aws_s3_bucket.logs.bucket))
    error_message = "S3 bucket names cannot contain uppercase letters or underscores. This is rejected by the API, not by Terraform - a plan will pass and the apply will fail."
  }

  assert {
    condition     = !can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+$", aws_s3_bucket.logs.bucket))
    error_message = "Bucket name must not be formatted as an IP address."
  }
}

# ---------------------------------------------------------------------------
# NOT GRADED HERE, AND THE REASON MATTERS:
#
#   Task 3 asks for  lifecycle { prevent_destroy = true }.
#
#   `lifecycle` is a META-ARGUMENT. It is not a resource attribute, so it does not
#   appear in the plan or in state, and `terraform test` therefore CANNOT see it.
#   An assertion claiming to check it would be checking nothing.
#
#   Verify it by exercise instead - the behaviour is the observable, not the source text:
#       terraform plan -destroy      # must FAIL with "Instance cannot be destroyed"
#
#   Grading the source text with grep would pass on a commented-out block.
# ---------------------------------------------------------------------------
