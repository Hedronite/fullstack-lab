#!/bin/sh
# Lab 11 (import and remote state) checker, POSIX sh (the lab image has no bash).
# Run it from a starter/ or reference/ tree (scripts/ci_gate.py copies it into a clean copy
# and runs `sh check.sh`). It never writes into that tree: the .tf files and the lock file are
# copied into a mktemp work dir (removed by a trap on EXIT/INT/TERM), the grader is staged
# there, and terraform runs through `env -i` with only PATH, LANG, a throwaway HOME,
# TF_IN_AUTOMATION=1 and TF_CLI_CONFIG_FILE. No AWS_*, TF_* or HOME from the caller reaches it.
# TF_CLI_CONFIG_FILE = $CI_GATE_TF_CLI_CONFIG if set (pass a provider-mirror-only file),
# else a generated mirror-only config when /opt/tf-mirror exists (the lab image), else /dev/null.
# The grader below is a byte-for-byte copy of graders/11-import-and-remote-state/
# hedronite_grader.tftest.hcl (ci_gate copies only this file); ci-gate.sh fails on drift.
# Also checks tasks 1, 2 and 3 statically (import block, moved block, use_lockfile, no dynamodb_table).
# Prints `RESULT 11-import-and-remote-state fix PASS|FAIL`; exit 0 PASS, 1 grader FAIL,
# 3 setup/init failure (no RESULT line, so a crash never counts as the expected FAIL).
set -u
lab=11-import-and-remote-state
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
# Hedronite lab 11 (import and remote state) grader.
# Staged as tests/hedronite_grader.tftest.hcl by curriculum/week1/tf/stage.sh.
# Offline by construction: mock_provider means no cloud credentials, no cloud calls, no cost.
# Needs Terraform >= 1.7 for mock_provider and override_*; the lab pins 1.10.5 (the lab image).
#
# What it sees: the plan graph after a mock apply. It cannot see import, moved or backend
# blocks (a mock provider cannot import, a test has no prior state, backends are skipped), so
# check.sh checks tasks 1, 2 and 3 statically. Task 4 is graded here: the platform
# configuration's state is replaced by override_data, and the artifacts bucket must take its
# name from that root output.

mock_provider "aws" {
  mock_resource "aws_s3_bucket" {
    defaults = {
      arn = "arn:aws:s3:::hx-mock"
    }
  }
}

# Stands in for the platform team's state snapshot; no S3 read happens.
override_data {
  target = data.terraform_remote_state.platform
  values = {
    outputs = {
      release_bucket_name = "hx-mock-from-remote-state"
    }
  }
}

# A mock provider cannot import, so the imported bucket is overridden with the values the real
# import would read. Without this override a correct import block would fail the test itself.
override_resource {
  target = aws_s3_bucket.legacy_logs
  values = {
    id  = "hx-lab11-legacy-logs"
    arn = "arn:aws:s3:::hx-lab11-legacy-logs"
  }
}

run "buckets_use_the_right_names" {
  command = apply

  assert {
    condition     = aws_s3_bucket.legacy_logs.bucket == "hx-lab11-legacy-logs"
    error_message = "The adopted bucket must keep the name of the real bucket, hx-lab11-legacy-logs."
  }

  assert {
    condition     = aws_s3_bucket.artifacts.bucket == "hx-mock-from-remote-state"
    error_message = "Task 4: the artifacts bucket name is typed in by hand. Read it from data.terraform_remote_state.platform.outputs.release_bucket_name."
  }
}
HEDRONITE_GRADER_EOF
if ! tf init -backend=false -input=false -lockfile=readonly -no-color >/dev/null; then
  echo "check.sh: terraform init failed (providers not available offline?); no verdict" >&2
  exit 3
fi
# Tasks 1, 2 and 3 are not visible to a plan or a mock-provider test, so they are checked
# statically on the .tf text: comments are stripped and whitespace is collapsed, so the
# formatting of a block (including spaces around =) does not matter but a commented-out block does not count. Every
# failure prints its task message; the grader still runs so task 4 reports too.
static=0
flat=$(cat ./*.tf | sed 's/#.*//; s://.*::' | tr -s ' \t\r\n' ' ' | sed 's/ *= */ = /g')
if ! printf '%s' "$flat" | grep -Eq 'import \{[^}]*to = aws_s3_bucket\.legacy_logs[^}]*id = "hx-lab11-legacy-logs"[^}]*\}|import \{[^}]*id = "hx-lab11-legacy-logs"[^}]*to = aws_s3_bucket\.legacy_logs[^}]*\}'; then
  echo "Task 1: no import block adopts hx-lab11-legacy-logs into aws_s3_bucket.legacy_logs (an import block needs to and id)."
  static=1
fi
if ! printf '%s' "$flat" | grep -Eq 'moved \{[^}]*from = aws_s3_bucket\.releases[^}]*to = aws_s3_bucket\.artifacts[^}]*\}|moved \{[^}]*to = aws_s3_bucket\.artifacts[^}]*from = aws_s3_bucket\.releases[^}]*\}'; then
  echo "Task 2: no moved block from aws_s3_bucket.releases to aws_s3_bucket.artifacts; the next plan would destroy and recreate the bucket."
  static=1
fi
if ! printf '%s' "$flat" | grep -Eq 'backend "s3" \{[^}]*use_lockfile = true'; then
  echo "Task 3: the s3 backend does not set use_lockfile = true (native state locking)."
  static=1
fi
if printf '%s' "$flat" | grep -Eq 'dynamodb_table[[:space:]]*='; then
  echo "Task 3: dynamodb_table is still set on the s3 backend; native locking does not need the table."
  static=1
fi
if tf test -no-color -filter=tests/hedronite_grader.tftest.hcl && [ "$static" -eq 0 ]; then r=PASS; else r=FAIL; fi
echo "RESULT $lab fix $r"
[ "$r" = PASS ]
