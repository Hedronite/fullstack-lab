#!/bin/sh
# Lab 01 (lifecycle guardrails) checker, POSIX sh (the lab image has no bash).
# Run it from a starter/ or reference/ tree (scripts/ci_gate.py copies it into a clean copy
# and runs `sh check.sh`). It never writes into that tree: the .tf files and the lock file are
# copied into a mktemp work dir (removed by a trap on EXIT/INT/TERM), the grader is staged
# there, and terraform runs through `env -i` with only PATH, LANG, a throwaway HOME,
# TF_IN_AUTOMATION=1 and TF_CLI_CONFIG_FILE. No AWS_*, TF_* or HOME from the caller reaches it.
# TF_CLI_CONFIG_FILE = $CI_GATE_TF_CLI_CONFIG if set (pass a provider-mirror-only file),
# else a generated mirror-only config when /opt/tf-mirror exists (the lab image), else /dev/null.
# The grader below is a byte-for-byte copy of graders/01-lifecycle-guardrails/
# hedronite_grader.tftest.hcl (ci_gate copies only this file); ci-gate.sh fails on drift.
# Prints `RESULT 01-lifecycle-guardrails fix PASS|FAIL`; exit 0 PASS, 1 grader FAIL,
# 3 setup/init failure (no RESULT line, so a crash never counts as the expected FAIL).
set -u
lab=01-lifecycle-guardrails
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
# Hedronite lab 01 (lifecycle guardrails) grader.
# Staged as tests/hedronite_grader.tftest.hcl by curriculum/week1/tf/stage.sh.
# Offline by construction: mock_provider means no cloud credentials, no cloud calls, no cost.
# Needs Terraform >= 1.7 for mock_provider; the lab pins 1.10.5 (the lab image).
#
# What a plan can and cannot show:
#   `lifecycle` is a meta-argument. prevent_destroy, ignore_changes and
#   create_before_destroy never appear in the plan or in state, so no assertion here can
#   see them. This grader checks the plan-visible preconditions (a real ledger name, and
#   name_prefix on the security group, without which create_before_destroy collides on the
#   fixed name). The lifecycle blocks themselves are checked by exercise in the README.

mock_provider "aws" {}

run "ledger_has_a_real_name" {
  command = plan

  assert {
    condition     = aws_dynamodb_table.audit_ledger.name != "<hx: name the audit ledger>"
    error_message = "Task 2: the ledger still has the <hx: ...> placeholder name."
  }

  assert {
    condition     = can(regex("^[A-Za-z0-9_.-]{3,255}$", aws_dynamodb_table.audit_ledger.name))
    error_message = "Task 2: a DynamoDB table name is 3-255 characters of letters, digits, '_', '-' and '.'. Plan does not catch this; the API rejects it at apply."
  }
}

run "edge_group_can_be_replaced_before_destroy" {
  command = plan

  assert {
    condition     = aws_security_group.ingress_edge.name_prefix == "hx-ingress-edge-"
    error_message = "Task 5: create_before_destroy needs the old and new group to coexist; a fixed `name` cannot. Use name_prefix = \"hx-ingress-edge-\" instead of name."
  }
}
HEDRONITE_GRADER_EOF
if ! tf init -backend=false -input=false -lockfile=readonly -no-color >/dev/null; then
  echo "check.sh: terraform init failed (providers not available offline?); no verdict" >&2
  exit 3
fi
if tf test -no-color -filter=tests/hedronite_grader.tftest.hcl; then r=PASS; else r=FAIL; fi
echo "RESULT $lab fix $r"
[ "$r" = PASS ]
