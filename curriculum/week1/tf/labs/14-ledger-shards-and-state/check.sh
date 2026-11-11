#!/bin/sh
# Lab 14 (ledger shards and state) checker, POSIX sh (the lab image has no bash).
# Run it from a starter/ or reference/ tree (scripts/ci_gate.py copies it into a clean copy
# and runs `sh check.sh`). It never writes into that tree: the .tf files and the lock file are
# copied into a mktemp work dir (removed by a trap on EXIT/INT/TERM), the grader is staged
# there, and terraform runs through `env -i` with only PATH, LANG, a throwaway HOME,
# TF_IN_AUTOMATION=1 and TF_CLI_CONFIG_FILE. No AWS_*, TF_* or HOME from the caller reaches it.
# TF_CLI_CONFIG_FILE = $CI_GATE_TF_CLI_CONFIG if set (pass a provider-mirror-only file),
# else a generated mirror-only config when /opt/tf-mirror exists (the lab image), else /dev/null.
# The grader below is a byte-for-byte copy of graders/14-ledger-shards-and-state/
# hedronite_grader.tftest.hcl (ci_gate copies only this file); ci-gate.sh fails on drift.
# Also greps main.tf (import with for_each, task 2; removed block, task 3), versions.tf and prod.s3.tfbackend (task 4).
# Prints `RESULT 14-ledger-shards-and-state fix PASS|FAIL`; exit 0 PASS, 1 grader FAIL,
# 3 setup/init failure (no RESULT line, so a crash never counts as the expected FAIL).
set -u
lab=14-ledger-shards-and-state
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
# Hedronite lab 14 (ledger shards and state) grader.
# Offline by construction: mock_provider means no cloud credentials, no cloud calls, no cost.
# Needs Terraform >= 1.7 for mock_provider and override_resource; the lab pins 1.10.5 (the lab image).
#
# What it sees: the plan graph after a mock apply. It grades task 1 (the shard set has all three
# real buckets). A mock provider cannot import, a test has no prior state and backends are
# skipped, so check.sh checks tasks 2 (import with for_each), 3 (removed block) and 4 (partial
# backend configuration with native locking) statically on the .tf text and the backend file.

mock_provider "aws" {
  mock_resource "aws_s3_bucket" {
    defaults = {
      arn = "arn:aws:s3:::hx-mock"
    }
  }
}

# A mock provider cannot import, so each adopted shard is overridden with the values the real
# import would read. Without these a correct import block would fail the test itself.
override_resource {
  target = aws_s3_bucket.shard["a"]
  values = {
    id  = "hx-lab14-a"
    arn = "arn:aws:s3:::hx-lab14-a"
  }
}

override_resource {
  target = aws_s3_bucket.shard["b"]
  values = {
    id  = "hx-lab14-b"
    arn = "arn:aws:s3:::hx-lab14-b"
  }
}

override_resource {
  target = aws_s3_bucket.shard["c"]
  values = {
    id  = "hx-lab14-c"
    arn = "arn:aws:s3:::hx-lab14-c"
  }
}

run "all_three_shards_are_managed" {
  command = apply

  assert {
    condition     = length(aws_s3_bucket.shard) == 3
    error_message = "Task 1: the account holds three shard buckets (a, b and c) but the configuration manages ${length(aws_s3_bucket.shard)}. Add the missing shard to var.shards."
  }

  assert {
    condition     = toset(output.shard_buckets) == toset(["hx-lab14-a", "hx-lab14-b", "hx-lab14-c"])
    error_message = "Task 1: shard_buckets must list hx-lab14-a, hx-lab14-b and hx-lab14-c."
  }
}
HEDRONITE_GRADER_EOF
if ! tf init -backend=false -input=false -lockfile=readonly -no-color >/dev/null; then
  echo "check.sh: terraform init failed (providers not available offline?); no verdict" >&2
  exit 3
fi
# Tasks 2, 3 and 4 are not visible to the mock apply, so they are checked statically on the
# .tf text and the backend file. Every failure prints its task message; the grader still runs.
static=0
if ! grep -Eq '^[[:space:]]*import[[:space:]]*\{' main.tf \
   || ! grep -Eq '^[[:space:]]*to[[:space:]]*=[[:space:]]*aws_s3_bucket\.shard\[each\.key\]' main.tf \
   || ! grep -Eq '^[[:space:]]*id[[:space:]]*=[[:space:]]*"hx-lab14-\$\{each\.key\}"' main.tf \
   || [ "$(grep -Ec '^[[:space:]]*for_each[[:space:]]*=[[:space:]]*var\.shards' main.tf)" -lt 2 ]; then
  echo "Task 2: no import block with for_each = var.shards, to = aws_s3_bucket.shard[each.key] and id = \"hx-lab14-\${each.key}\"."
  static=1
fi
if grep -Eq '^[[:space:]]*resource[[:space:]]+"aws_s3_bucket"[[:space:]]+"scratch_ledger"' main.tf \
   || ! grep -Eq '^[[:space:]]*removed[[:space:]]*\{' main.tf \
   || ! grep -Eq '^[[:space:]]*from[[:space:]]*=[[:space:]]*aws_s3_bucket\.scratch_ledger[[:space:]]*$' main.tf \
   || ! grep -Eq '^[[:space:]]*destroy[[:space:]]*=[[:space:]]*false' main.tf; then
  echo "Task 3: scratch_ledger must be forgotten, not destroyed: delete its resource block and add a removed block (from = aws_s3_bucket.scratch_ledger, lifecycle { destroy = false })."
  static=1
fi
if grep -Eq '^[[:space:]]*(bucket|key)[[:space:]]*=' versions.tf \
   || ! grep -Eq '^[[:space:]]*use_lockfile[[:space:]]*=[[:space:]]*true' versions.tf \
   || ! grep -Eq '^[[:space:]]*bucket[[:space:]]*=' "$src/prod.s3.tfbackend" 2>/dev/null \
   || ! grep -Eq '^[[:space:]]*key[[:space:]]*=' "$src/prod.s3.tfbackend" 2>/dev/null; then
  echo "Task 4: the s3 backend block must not hold bucket or key (partial configuration), must set use_lockfile = true, and prod.s3.tfbackend must supply bucket and key."
  static=1
fi
if tf test -no-color -filter=tests/hedronite_grader.tftest.hcl && [ "$static" -eq 0 ]; then r=PASS; else r=FAIL; fi
echo "RESULT $lab fix $r"
[ "$r" = PASS ]
