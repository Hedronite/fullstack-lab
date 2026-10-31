#!/bin/sh
# Lab 01 root checker, for scripts/ci_gate.py (it copies this file into a clean copy of
# starter/ or reference/ and runs `sh check.sh` there, in hedronite/fullstack-lab-tf).
# POSIX sh on purpose: the lab image has no bash.
# The grader below is a byte-for-byte copy of graders/01-lifecycle-cli-broken/
# hedronite_grader.tftest.hcl (ci_gate copies only this file, so it must carry the grader).
# ci-gate.sh fails if the two copies drift.
# Prints `RESULT 01-lifecycle-cli-broken fix PASS|FAIL` and exits 0 on PASS, 1 on a grader
# FAIL. An init failure (no provider, no network) prints no RESULT line and exits 3, so a
# gate never counts a crash as the starter's expected FAIL.
set -u
lab=01-lifecycle-cli-broken
mkdir -p tests
cat > tests/hedronite_grader.tftest.hcl <<'HEDRONITE_GRADER_EOF'
# Lab 01 — Lifecycle and CLI  ·  grader
# Staged as tests/hedronite_grader.tftest.hcl by curriculum/week1/tf/stage.sh.
# Run with: terraform init && terraform test
#
# Offline by construction: mock_provider means NO cloud credentials, NO cloud calls, NO cost.
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
HEDRONITE_GRADER_EOF
if ! terraform init -backend=false -input=false -no-color >/dev/null; then
  echo "check.sh: terraform init failed (providers not available?); no verdict" >&2
  exit 3
fi
if terraform test -no-color -filter=tests/hedronite_grader.tftest.hcl; then r=PASS; else r=FAIL; fi
echo "RESULT $lab fix $r"
[ "$r" = PASS ]
