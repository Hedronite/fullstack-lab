# Hedronite lab 13 (release ledger guardrails) grader.
# Offline by construction: mock_provider means no cloud credentials, no cloud calls, no cost.
# Needs Terraform >= 1.7 for mock_provider; the lab pins 1.10.5 (the lab image).
#
# The run applies the configuration against the mock provider and checks that the ledger
# bucket keeps object versions (task 1a). ignore_changes (task 1b), the moved block (task 2)
# and the Terraform version bound (task 3) are not observable in a mock apply over a fresh state, so check.sh checks them
# statically on the .tf text.

mock_provider "aws" {}

run "ledger_keeps_versions" {
  command = apply

  assert {
    condition     = aws_s3_bucket_versioning.ledger.versioning_configuration[0].status == "Enabled"
    error_message = "Task 1a: the ledger bucket must keep every object version (status must be Enabled), or an overwritten ledger line cannot be recovered."
  }
}
