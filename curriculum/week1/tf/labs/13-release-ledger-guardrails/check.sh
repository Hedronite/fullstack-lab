#!/bin/sh
# Lab 13 (release ledger guardrails) checker, POSIX sh (the lab image has no bash).
# Run it from a starter/ or reference/ tree (scripts/ci_gate.py copies it into a clean copy
# and runs `sh check.sh`). It never writes into that tree: the .tf files and the lock file are
# copied into a mktemp work dir (removed by a trap on EXIT/INT/TERM), the grader is staged
# there, and terraform runs through `env -i` with only PATH, LANG, a throwaway HOME,
# TF_IN_AUTOMATION=1 and TF_CLI_CONFIG_FILE. No AWS_*, TF_* or HOME from the caller reaches it.
# TF_CLI_CONFIG_FILE = $CI_GATE_TF_CLI_CONFIG if set (pass a provider-mirror-only file),
# else a generated mirror-only config when /opt/tf-mirror exists (the lab image), else /dev/null.
# The grader below is a byte-for-byte copy of graders/13-release-ledger-guardrails/
# hedronite_grader.tftest.hcl (ci_gate copies only this file); ci-gate.sh fails on drift.
# Also greps main.tf (ignore_changes, task 1b; moved block, task 2) and versions.tf (required_version, task 3).
# Prints `RESULT 13-release-ledger-guardrails fix PASS|FAIL`; exit 0 PASS, 1 grader FAIL,
# 3 setup/init failure (no RESULT line, so a crash never counts as the expected FAIL).
set -u
lab=13-release-ledger-guardrails
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
HEDRONITE_GRADER_EOF
if ! tf init -backend=false -input=false -lockfile=readonly -no-color >/dev/null; then
  echo "check.sh: terraform init failed (providers not available offline?); no verdict" >&2
  exit 3
fi
# Tasks 1b, 2 and 3 are not visible to the mock apply, so they are checked statically
# on the .tf text. Every failure prints its task message; the grader still runs.
static=0
if ! grep -Eq '^[[:space:]]*ignore_changes[[:space:]]*=[[:space:]]*\[[[:space:]]*tags[[:space:]]*\]' main.tf; then
  echo "Task 1b: aws_s3_bucket.ledger has no lifecycle ignore_changes = [tags]."
  static=1
fi
if ! grep -Eq '^[[:space:]]*moved[[:space:]]*\{' main.tf \
   || ! grep -Eq '^[[:space:]]*from[[:space:]]*=[[:space:]]*aws_s3_bucket\.soak_ledger[[:space:]]*$' main.tf \
   || ! grep -Eq '^[[:space:]]*to[[:space:]]*=[[:space:]]*aws_s3_bucket\.ledger[[:space:]]*$' main.tf; then
  echo "Task 2: no moved block from aws_s3_bucket.soak_ledger to aws_s3_bucket.ledger."
  static=1
fi
if ! grep -Eq '^[[:space:]]*required_version[[:space:]]*=[[:space:]]*"~>[[:space:]]*1\.10"' versions.tf; then
  echo "Task 3: required_version is not bounded to the 1.10 series (for example \"~> 1.10\")."
  static=1
fi
if tf test -no-color -filter=tests/hedronite_grader.tftest.hcl && [ "$static" -eq 0 ]; then r=PASS; else r=FAIL; fi
echo "RESULT $lab fix $r"
[ "$r" = PASS ]
