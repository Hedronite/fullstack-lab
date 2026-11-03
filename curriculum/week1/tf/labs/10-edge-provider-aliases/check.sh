#!/bin/sh
# Lab 10 (edge provider aliases) checker, POSIX sh (the lab image has no bash).
# Run it from a starter/ or reference/ tree (scripts/ci_gate.py copies it into a clean copy
# and runs `sh check.sh`). It never writes into that tree: the .tf files and the lock file are
# copied into a mktemp work dir (removed by a trap on EXIT/INT/TERM), the grader is staged
# there, and terraform runs through `env -i` with only PATH, LANG, a throwaway HOME,
# TF_IN_AUTOMATION=1 and TF_CLI_CONFIG_FILE. No AWS_*, TF_* or HOME from the caller reaches it.
# TF_CLI_CONFIG_FILE = $CI_GATE_TF_CLI_CONFIG if set (pass a provider-mirror-only file),
# else a generated mirror-only config when /opt/tf-mirror exists (the lab image), else /dev/null.
# The grader below is a byte-for-byte copy of graders/10-edge-provider-aliases/
# hedronite_grader.tftest.hcl (ci_gate copies only this file); ci-gate.sh fails on drift.
# Also greps versions.tf for tasks 2 and 3 (version bound, no static keys, assume_role).
# Prints `RESULT 10-edge-provider-aliases fix PASS|FAIL`; exit 0 PASS, 1 grader FAIL,
# 3 setup/init failure (no RESULT line, so a crash never counts as the expected FAIL).
set -u
lab=10-edge-provider-aliases
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
# Hedronite lab 10 (edge provider aliases) grader.
# Staged as tests/hedronite_grader.tftest.hcl by curriculum/week1/tf/stage.sh.
# Offline by construction: mock_provider means no cloud credentials, no cloud calls, no cost.
# Needs Terraform >= 1.7 for mock_provider; the lab pins 1.10.5 (the lab image).
#
# How it sees the provider: each mock_provider gives aws_s3_bucket a different computed
# `arn`, so the arn a bucket ends up with tells which provider configuration managed it.
# Version constraints and provider credentials are not visible to a plan; check.sh
# checks those two (tasks 2 and 3) statically.

mock_provider "aws" {
  mock_resource "aws_s3_bucket" {
    defaults = {
      arn = "arn:aws:s3:::hx-mock-primary"
    }
  }
}

mock_provider "aws" {
  alias = "dr"

  mock_resource "aws_s3_bucket" {
    defaults = {
      arn = "arn:aws:s3:::hx-mock-dr"
    }
  }
}

run "buckets_land_in_the_right_region" {
  # apply against the mock providers (offline, nothing real is created): computed
  # attributes such as arn are unknown at plan time and only filled in after a mock apply.
  command = apply

  assert {
    condition     = aws_s3_bucket.releases.arn == "arn:aws:s3:::hx-mock-primary"
    error_message = "The primary release bucket must stay on the default aws provider."
  }

  assert {
    condition     = aws_s3_bucket.releases_dr.arn == "arn:aws:s3:::hx-mock-dr"
    error_message = "Task 1: the replica bucket is managed by the default provider. Add provider = aws.dr so it is created through the aliased provider (second region)."
  }
}
HEDRONITE_GRADER_EOF
if ! tf init -backend=false -input=false -lockfile=readonly -no-color >/dev/null; then
  echo "check.sh: terraform init failed (providers not available offline?); no verdict" >&2
  exit 3
fi
# Tasks 2 and 3 are not visible to a plan, so they are checked statically on the .tf text.
# Every failure prints its task message; the grader still runs so task 1 reports too.
static=0
if ! grep -Eq '^[[:space:]]*version[[:space:]]*=[[:space:]]*"(~>[[:space:]]*6\.71|=[[:space:]]*6\.71\.0)"' versions.tf; then
  echo "Task 2: the aws provider version constraint is too loose; bound it to the 6.71 series (for example \"~> 6.71\")."
  static=1
fi
if grep -Eq '^[[:space:]]*(access_key|secret_key)[[:space:]]*=' *.tf; then
  echo "Task 3: static access_key/secret_key in a provider block; remove them and authenticate through the environment plus assume_role."
  static=1
fi
if ! grep -Eq '^[[:space:]]*assume_role[[:space:]]*\{' versions.tf; then
  echo "Task 3: the aliased provider has no assume_role block for var.dr_role_arn."
  static=1
fi
if tf test -no-color -filter=tests/hedronite_grader.tftest.hcl && [ "$static" -eq 0 ]; then r=PASS; else r=FAIL; fi
echo "RESULT $lab fix $r"
[ "$r" = PASS ]
