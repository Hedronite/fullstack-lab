#!/bin/sh
# Lab 20 (ledger archive: moved block and remote state) checker, POSIX sh (the lab image has no bash).
# Run it from a starter/ or reference/ tree (scripts/ci_gate.py copies it into a clean copy
# and runs `sh check.sh`). It never writes into that tree: the .tf files and the lock file are
# copied into a mktemp work dir (removed by a trap on EXIT/INT/TERM), the grader is staged
# there, and terraform runs through `env -i` with only PATH, LANG, a throwaway HOME,
# TF_IN_AUTOMATION=1 and TF_CLI_CONFIG_FILE. No AWS_*, TF_* or HOME from the caller reaches it.
# TF_CLI_CONFIG_FILE = $CI_GATE_TF_CLI_CONFIG if set (pass a provider-mirror-only file),
# else a generated mirror-only config when /opt/tf-mirror exists (the lab image), else /dev/null.
# The grader below is a byte-for-byte copy of graders/20-ledger-archive-moved-and-remote-state/
# hedronite_grader.tftest.hcl (ci_gate copies only this file); ci-gate.sh fails on drift.
# Also greps main.tf (moved block, task 1).
# Prints `RESULT 20-ledger-archive-moved-and-remote-state fix PASS|FAIL`; exit 0 PASS, 1 grader FAIL,
# 3 setup/init failure (no RESULT line, so a crash never counts as the expected FAIL).
set -u
lab=20-ledger-archive-moved-and-remote-state
src=$(pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/hx-check.XXXXXX") || exit 3
trap 'rm -rf "$work"' EXIT
trap 'rm -rf "$work"; exit 130' INT
trap 'rm -rf "$work"; exit 143' TERM
mkdir -p "$work/ws/tests" "$work/home" || exit 3
cp "$src"/*.tf "$work/ws/" || { echo "check.sh: no .tf files in $src" >&2; exit 3; }
[ -f "$src/.terraform.lock.hcl" ] && cp "$src/.terraform.lock.hcl" "$work/ws/"
if [ -n "${CI_GATE_TF_CLI_CONFIG:-}" ]; then cfg=$CI_GATE_TF_CLI_CONFIG
elif [ -d /opt/tf-mirror ]; then
  cfg=$work/mirror.tfrc
  printf 'provider_installation {\n  filesystem_mirror {\n    path = "/opt/tf-mirror"\n  }\n}\n' > "$cfg"
else cfg=/dev/null; fi
tf() { env -i PATH="$PATH" LANG="${LANG:-C.UTF-8}" HOME="$work/home" TF_IN_AUTOMATION=1 TF_CLI_CONFIG_FILE="$cfg" terraform "$@"; }
cd "$work/ws" || exit 3
cat > tests/hedronite_grader.tftest.hcl <<'HEDRONITE_GRADER_EOF'
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
HEDRONITE_GRADER_EOF
if ! tf init -backend=false -input=false -lockfile=readonly -no-color >/dev/null; then
  echo "check.sh: terraform init failed (providers not available offline?); no verdict" >&2
  exit 3
fi
# Task 1 is not visible to a mock apply on empty state, so it is checked statically on the .tf
# text. Every failure prints its task message; the grader still runs.
static=0
if ! grep -Eq '^[[:space:]]*moved[[:space:]]*\{' main.tf \
   || ! grep -Eq '^[[:space:]]*from[[:space:]]*=[[:space:]]*aws_s3_bucket\.ledger[[:space:]]*$' main.tf \
   || ! grep -Eq '^[[:space:]]*to[[:space:]]*=[[:space:]]*aws_s3_bucket\.archive[[:space:]]*$' main.tf; then
  echo "Task 1: no moved block from aws_s3_bucket.ledger to aws_s3_bucket.archive."
  static=1
fi
if tf test -no-color -filter=tests/hedronite_grader.tftest.hcl && [ "$static" -eq 0 ]; then r=PASS; else r=FAIL; fi
echo "RESULT $lab fix $r"
[ "$r" = PASS ]
