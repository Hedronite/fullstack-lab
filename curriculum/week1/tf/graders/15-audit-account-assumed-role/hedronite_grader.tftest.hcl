# Hedronite lab 15 (audit account and assumed role) grader.
# Staged as tests/hedronite_grader.tftest.hcl by curriculum/week1/tf/stage.sh.
# Offline by construction: mock_provider means no cloud credentials, no cloud calls, no cost.
# Needs Terraform >= 1.8 for issensitive() and >= 1.7 for mock_provider; the lab pins 1.10.5.
#
# What it sees: two mock providers whose buckets carry different ARNs, so a resource that
# was sent to the wrong provider configuration shows up in its ARN. Task 1 (provider routing)
# and task 2 (sensitive variable and output) are graded here. The mock providers replace the
# provider blocks, so task 3 (assume_role instead of static keys) and the "no default on the
# key" half of task 2 are checked statically by check.sh.

mock_provider "aws" {
  mock_resource "aws_s3_bucket" {
    defaults = {
      arn = "arn:aws:s3:::mock-edge-account-bucket"
    }
  }
}

mock_provider "aws" {
  alias = "audit"

  mock_resource "aws_s3_bucket" {
    defaults = {
      arn = "arn:aws:s3:::mock-audit-account-bucket"
    }
  }
}

variables {
  sink_api_key = "hx-test-sink-key-1"
}

run "audit_bucket_in_audit_account" {
  command = apply

  assert {
    condition     = aws_s3_bucket.edge_logs.arn == "arn:aws:s3:::mock-edge-account-bucket"
    error_message = "The edge logs bucket should stay in the edge account (default provider)."
  }

  assert {
    condition     = aws_s3_bucket.audit_logs.arn == "arn:aws:s3:::mock-audit-account-bucket"
    error_message = "Task 1: aws_s3_bucket.audit_logs was created through the default provider, so it lands in the edge account. Add provider = aws.audit."
  }
}

run "sink_key_stays_secret" {
  command = apply

  assert {
    condition     = issensitive(var.sink_api_key)
    error_message = "Task 2: var.sink_api_key is not marked sensitive, so plan and apply would print it."
  }

  assert {
    condition     = issensitive(output.sink_url)
    error_message = "Task 2: output.sink_url contains the sink API key but is not marked sensitive."
  }
}
