#!/bin/sh
# Lab 19 (queue retry and dead letters) checker, POSIX sh (the lab image has no bash).
# Run it from a starter/ or reference/ tree (scripts/ci_gate.py copies it into a clean copy
# and runs `sh check.sh`). It never writes into that tree: the .tf files and the lock file are
# copied into a mktemp work dir (removed by a trap on EXIT/INT/TERM), the grader is staged
# there, and terraform runs through `env -i` with only PATH, LANG, a throwaway HOME,
# TF_IN_AUTOMATION=1 and TF_CLI_CONFIG_FILE. No AWS_*, TF_* or HOME from the caller reaches it.
# TF_CLI_CONFIG_FILE = $CI_GATE_TF_CLI_CONFIG if set (pass a provider-mirror-only file),
# else a generated mirror-only config when /opt/tf-mirror exists (the lab image), else /dev/null.
# The grader below is a byte-for-byte copy of graders/19-queue-retry-and-dead-letters/
# hedronite_grader.tftest.hcl (ci_gate copies only this file); ci-gate.sh fails on drift.
# Also greps main.tf (import block, task 2) and versions.tf (required_version and provider bound, task 3).
# Prints `RESULT 19-queue-retry-and-dead-letters fix PASS|FAIL`; exit 0 PASS, 1 grader FAIL,
# 3 setup/init failure (no RESULT line, so a crash never counts as the expected FAIL).
set -u
lab=19-queue-retry-and-dead-letters
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
# Hedronite lab 19 (queue retry and dead letters) grader.
# Offline by construction: mock_provider means no cloud credentials, no cloud calls, no cost.
# Needs Terraform >= 1.7 for mock_provider; the lab pins 1.10.5 (the lab image).
#
# The run applies the configuration against the mock provider and checks the retention period
# (task 1a) and the redrive limit (task 1b). The import block (task 2) and the version bounds
# (task 3) are not observable in a mock apply, so check.sh checks them statically on the .tf text.

mock_provider "aws" {}

# A mock provider cannot import, so the adopted dead-letter queue is overridden with fixed values.
override_resource {
  target = aws_sqs_queue.dlq
  values = {
    arn = "arn:aws:sqs:us-east-1:123456789012:hx-lab19-events-dlq"
  }
}

run "queue_keeps_messages_and_gives_up_on_poison" {
  command = apply

  assert {
    condition     = aws_sqs_queue.events.message_retention_seconds >= 345600
    error_message = "Task 1a: message_retention_seconds must be at least 345600 (4 days), or messages expire during a long outage."
  }

  assert {
    condition     = jsondecode(aws_sqs_queue.events.redrive_policy).maxReceiveCount <= 5
    error_message = "Task 1b: maxReceiveCount must be 5 or less, so a poison message reaches the dead-letter queue quickly."
  }
}
HEDRONITE_GRADER_EOF
if ! tf init -backend=false -input=false -lockfile=readonly -no-color >/dev/null; then
  echo "check.sh: terraform init failed (providers not available offline?); no verdict" >&2
  exit 3
fi
# Tasks 2 and 3 are not visible to the mock apply, so they are checked statically
# on the .tf text. Every failure prints its task message; the grader still runs.
static=0
if ! grep -Eq '^[[:space:]]*import[[:space:]]*\{' main.tf \
   || ! grep -Eq '^[[:space:]]*to[[:space:]]*=[[:space:]]*aws_sqs_queue\.dlq[[:space:]]*$' main.tf \
   || ! grep -Eq '^[[:space:]]*id[[:space:]]*=[[:space:]]*"[^"]*hx-lab19-events-dlq"' main.tf; then
  echo "Task 2: no import block for aws_sqs_queue.dlq with the existing queue URL as id."
  static=1
fi
if ! grep -Eq '^[[:space:]]*required_version[[:space:]]*=[[:space:]]*"~>[[:space:]]*1\.10"' versions.tf; then
  echo "Task 3a: required_version is not bounded to the 1.10 series (for example \"~> 1.10\")."
  static=1
fi
if ! grep -Eq '^[[:space:]]*version[[:space:]]*=[[:space:]]*"~>[[:space:]]*6\.71"' versions.tf; then
  echo "Task 3b: the aws provider version is not bounded with \"~> 6.71\"."
  static=1
fi
if tf test -no-color -filter=tests/hedronite_grader.tftest.hcl && [ "$static" -eq 0 ]; then r=PASS; else r=FAIL; fi
echo "RESULT $lab fix $r"
[ "$r" = PASS ]
