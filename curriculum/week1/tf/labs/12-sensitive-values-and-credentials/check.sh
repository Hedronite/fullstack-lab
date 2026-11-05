#!/bin/sh
# Lab 12 (sensitive values and credentials) checker, POSIX sh (the lab image has no bash).
# Run it from a starter/ or reference/ tree (scripts/ci_gate.py copies it into a clean copy
# and runs `sh check.sh`). It never writes into that tree: the .tf files and the lock file are
# copied into a mktemp work dir (removed by a trap on EXIT/INT/TERM), the grader is staged
# there, and terraform runs through `env -i` with only PATH, LANG, a throwaway HOME,
# TF_IN_AUTOMATION=1 and TF_CLI_CONFIG_FILE. No AWS_*, TF_* or HOME from the caller reaches it.
# TF_CLI_CONFIG_FILE = $CI_GATE_TF_CLI_CONFIG if set (pass a provider-mirror-only file),
# else a generated mirror-only config when /opt/tf-mirror exists (the lab image), else /dev/null.
# The grader below is a byte-for-byte copy of graders/12-sensitive-values-and-credentials/
# hedronite_grader.tftest.hcl (ci_gate copies only this file); ci-gate.sh fails on drift.
# Also checks statically: no default on var.db_password (task 1) and no provider credentials
# in configuration (task 4).
# Prints `RESULT 12-sensitive-values-and-credentials fix PASS|FAIL`; exit 0 PASS, 1 grader FAIL,
# 3 setup/init failure (no RESULT line, so a crash never counts as the expected FAIL).
set -u
lab=12-sensitive-values-and-credentials
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
# Hedronite lab 12 (sensitive values and credentials) grader.
# Staged as tests/hedronite_grader.tftest.hcl by curriculum/week1/tf/stage.sh.
# Offline by construction: mock_provider means no cloud credentials, no cloud calls, no cost.
# Needs Terraform >= 1.8 for issensitive() and >= 1.7 for mock_provider; the lab pins 1.10.5.
#
# What it sees: the plan graph after a mock apply. It can ask whether a value carries the
# sensitive mark (issensitive), so tasks 1, 2 and 3 are graded here. The provider block is
# replaced by the mock provider, so task 4 (no credentials in configuration) and the "no default
# on the password" half of task 1 are checked statically by check.sh.

mock_provider "aws" {
  mock_resource "aws_db_instance" {
    defaults = {
      address = "hx-lab12-edge.mock.internal"
    }
  }
}

variables {
  db_password = "hx-test-password-1"
}

run "secret_stays_secret" {
  command = apply

  assert {
    condition     = issensitive(var.db_password)
    error_message = "Task 1: var.db_password is not marked sensitive, so plan and apply would print it."
  }

  assert {
    condition     = issensitive(output.db_connection_string)
    error_message = "Task 2: output.db_connection_string contains the password but is not marked sensitive."
  }

  assert {
    condition     = alltrue([for v in values(aws_db_instance.edge.tags) : nonsensitive(v) != nonsensitive(var.db_password)])
    error_message = "Task 3: a tag on aws_db_instance.edge carries the password in plain text."
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
if printf '%s' "$flat" | grep -Eq 'variable "db_password" \{[^}]*[[:space:]]default = '; then
  echo "Task 1: variable db_password still has a default; a run that forgets to supply it would use the one in the code."
  static=1
fi
if printf '%s' "$flat" | grep -Eq '(^|[[:space:]])(access_key|secret_key|token) = |variable "aws_(access|secret)_key"'; then
  echo "Task 4: provider credentials are still in configuration (access_key, secret_key, token or a variable that feeds them)."
  static=1
fi
if tf test -no-color -filter=tests/hedronite_grader.tftest.hcl && [ "$static" -eq 0 ]; then r=PASS; else r=FAIL; fi
echo "RESULT $lab fix $r"
[ "$r" = PASS ]
