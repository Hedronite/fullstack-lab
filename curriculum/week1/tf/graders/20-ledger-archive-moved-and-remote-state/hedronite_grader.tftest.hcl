# Hedronite lab 20 (ledger archive: moved block and remote state) grader.
# Offline by construction: mock_provider means no cloud credentials, no cloud calls, no cost.
# Needs Terraform >= 1.7 for mock_provider and override_data; the lab pins 1.10.5 (the lab image).
#
# The run applies the configuration against the mock provider and checks versioning (task 2a)
# and that the encryption key comes from the platform remote state (task 2b). The remote state
# read is replaced by override_data, so no backend is contacted. The moved block
# (task 1) is not observable in a mock apply on empty state, so check.sh
# checks them statically on the .tf text.

mock_provider "aws" {}

override_data {
  target = data.terraform_remote_state.platform
  values = {
    outputs = {
      kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/hx-lab20-platform"
    }
  }
}

run "archive_keeps_history_and_uses_the_platform_key" {
  command = apply

  assert {
    condition     = aws_s3_bucket_versioning.archive.versioning_configuration[0].status == "Enabled"
    error_message = "Task 2a: versioning status must be Enabled, or an overwrite destroys history."
  }

  assert {
    condition     = one(aws_s3_bucket_server_side_encryption_configuration.archive.rule).apply_server_side_encryption_by_default[0].kms_master_key_id == "arn:aws:kms:us-east-1:123456789012:key/hx-lab20-platform"
    error_message = "Task 2b: kms_master_key_id must come from the platform remote state output kms_key_arn, not a pasted ARN."
  }
}
