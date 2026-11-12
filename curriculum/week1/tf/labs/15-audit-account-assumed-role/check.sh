#!/bin/sh
# Lab 15 (audit account and assumed role) checker, POSIX sh (the lab image has no bash).
# Run it from a starter/ or reference/ tree (scripts/ci_gate.py copies it into a clean copy
# and runs `sh check.sh`). It never writes into that tree: the .tf files and the lock file are
# copied into a mktemp work dir (removed by a trap on EXIT/INT/TERM), the grader is staged
# there, and terraform runs through `env -i` with only PATH, LANG, a throwaway HOME,
# TF_IN_AUTOMATION=1 and TF_CLI_CONFIG_FILE. No AWS_*, TF_* or HOME from the caller reaches it.
# TF_CLI_CONFIG_FILE = $CI_GATE_TF_CLI_CONFIG if set (pass a provider-mirror-only file),
# else a generated mirror-only config when /opt/tf-mirror exists (the lab image), else /dev/null.
# The grader below is a byte-for-byte copy of graders/15-audit-account-assumed-role/
# hedronite_grader.tftest.hcl (ci_gate copies only this file); ci-gate.sh fails on drift.
# Also checks statically: no default on var.sink_api_key (task 2), no static credentials on the
# audit provider and an assume_role block with a role_arn (task 3).
# Prints `RESULT 15-audit-account-assumed-role fix PASS|FAIL`; exit 0 PASS, 1 grader FAIL,
# 3 setup/init failure (no RESULT line, so a crash never counts as the expected FAIL).
set -u
lab=15-audit-account-assumed-role
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
HEDRONITE_GRADER_EOF
if ! tf init -backend=false -input=false -lockfile=readonly -no-color >/dev/null; then
  echo "check.sh: terraform init failed (providers not available offline?); no verdict" >&2
  exit 3
fi
# The mock provider replaces the provider block and a test has no prior state, so two things
# are checked statically on the .tf text: comments are stripped and whitespace is collapsed, so
# layout does not matter but a commented-out line does not count. Every failure prints its task
# message; the grader still runs so tasks 1 to 3 report too.
static=0
flat=$(cat ./*.tf | sed 's/#.*//; s://.*::' | tr -s ' \t\r\n' ' ' | sed 's/ *= */ = /g')
if printf '%s' "$flat" | grep -Eq 'variable "sink_api_key" \{[^}]*[[:space:]]default = '; then
  echo "Task 2: variable sink_api_key still has a default; a run that forgets to supply it would use the one in the code."
  static=1
fi
if printf '%s' "$flat" | grep -Eq '(^|[[:space:]])(access_key|secret_key|token) = |variable "audit_(access|secret)_key"'; then
  echo "Task 3: the audit provider still has static credentials in configuration (access_key, secret_key, token or a variable that feeds them)."
  static=1
fi
if ! printf '%s' "$flat" | grep -Eq 'alias = "audit" [^}]*assume_role \{[^}]*role_arn = '; then
  echo "Task 3: the audit provider has no assume_role block with a role_arn."
  static=1
fi
if tf test -no-color -filter=tests/hedronite_grader.tftest.hcl && [ "$static" -eq 0 ]; then r=PASS; else r=FAIL; fi
echo "RESULT $lab fix $r"
[ "$r" = PASS ]
