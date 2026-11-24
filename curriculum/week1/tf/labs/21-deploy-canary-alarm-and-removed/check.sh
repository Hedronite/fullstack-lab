#!/bin/sh
# Lab 21 (deploy canary alarm and removed) checker, POSIX sh (the lab image has no bash).
# Run it from a starter/ or reference/ tree (scripts/ci_gate.py copies it into a clean copy
# and runs `sh check.sh`). It never writes into that tree: the .tf files and the lock file are
# copied into a mktemp work dir (removed by a trap on EXIT/INT/TERM), the grader is staged
# there, and terraform runs through `env -i` with only PATH, LANG, a throwaway HOME,
# TF_IN_AUTOMATION=1 and TF_CLI_CONFIG_FILE. No AWS_*, TF_* or HOME from the caller reaches it.
# TF_CLI_CONFIG_FILE = $CI_GATE_TF_CLI_CONFIG if set (pass a provider-mirror-only file),
# else a generated mirror-only config when /opt/tf-mirror exists (the lab image), else /dev/null.
# The grader below is a byte-for-byte copy of graders/21-deploy-canary-alarm-and-removed/
# hedronite_grader.tftest.hcl (ci_gate copies only this file); ci-gate.sh fails on drift.
# Also greps main.tf (create_before_destroy, task 2; removed block, task 3).
# Prints `RESULT 21-deploy-canary-alarm-and-removed fix PASS|FAIL`; exit 0 PASS, 1 grader FAIL,
# 3 setup/init failure (no RESULT line, so a crash never counts as the expected FAIL).
set -u
lab=21-deploy-canary-alarm-and-removed
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
# Hedronite lab 21 (deploy canary alarm and removed block) grader.
# Offline by construction: mock_provider means no cloud credentials, no cloud calls, no cost.
# Needs Terraform >= 1.7 for mock_provider; the lab pins 1.10.5 (the lab image).
#
# The run applies the configuration against the mock provider and checks the alarm's evaluation
# periods (task 1a), missing-data handling (task 1b) and notification target (task 1c).
# create_before_destroy (task 2) and the removed block (task 3) are not observable in a mock
# apply, so check.sh checks them statically on the .tf text.

mock_provider "aws" {}

# The mock provider generates a random string for computed attributes, which the alarm's ARN
# validation rejects, so the topic gets a fixed, valid ARN.
override_resource {
  target = aws_sns_topic.alerts
  values = {
    arn = "arn:aws:sns:us-east-1:123456789012:hx-lab21-canary-alerts"
  }
}

run "canary_alarm_is_patient_strict_and_wired" {
  command = apply

  assert {
    condition     = aws_cloudwatch_metric_alarm.canary_errors.evaluation_periods >= 2
    error_message = "Task 1a: evaluation_periods must be at least 2, so one bad minute does not trip the alarm."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.canary_errors.treat_missing_data == "breaching"
    error_message = "Task 1b: treat_missing_data must be \"breaching\", so a silent canary counts as unhealthy."
  }

  assert {
    condition     = contains(aws_cloudwatch_metric_alarm.canary_errors.alarm_actions, aws_sns_topic.alerts.arn)
    error_message = "Task 1c: alarm_actions must contain the alerts topic ARN."
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
if ! awk '/^resource "aws_sns_topic" "alerts"/{f=1} f&&/create_before_destroy[[:space:]]*=[[:space:]]*true/{ok=1} f&&/^}/{f=0} END{exit !ok}' main.tf; then
  echo "Task 2: aws_sns_topic.alerts has no lifecycle { create_before_destroy = true }."
  static=1
fi
if grep -Eq '^resource "aws_cloudwatch_metric_alarm" "legacy_latency"' main.tf; then
  echo "Task 3: aws_cloudwatch_metric_alarm.legacy_latency is still a managed resource; remove it."
  static=1
fi
if ! awk '/^removed[[:space:]]*\{/{f=1} f&&/from[[:space:]]*=[[:space:]]*aws_cloudwatch_metric_alarm\.legacy_latency[[:space:]]*$/{a=1} f&&/destroy[[:space:]]*=[[:space:]]*false/{b=1} END{exit !(a&&b)}' main.tf; then
  echo "Task 3: no removed block for aws_cloudwatch_metric_alarm.legacy_latency with destroy = false."
  static=1
fi
if tf test -no-color -filter=tests/hedronite_grader.tftest.hcl && [ "$static" -eq 0 ]; then r=PASS; else r=FAIL; fi
echo "RESULT $lab fix $r"
[ "$r" = PASS ]
