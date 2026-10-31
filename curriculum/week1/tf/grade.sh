#!/usr/bin/env bash
# Run our graders against staged labs: init + test in each, one RESULT line per lab.
#   curriculum/week1/tf/grade.sh <dest> [lab-prefix ...]
# Uses `terraform` from PATH (>= 1.7). Graders use mock providers. Terraform runs
# with a cleared environment; only these pass through: PATH, a throwaway HOME
# (mktemp, removed on exit), TF_CLI_CONFIG_FILE=/dev/null, TF_IN_AUTOMATION=1 and,
# if set, TF_PLUGIN_CACHE_DIR. No cloud credentials or CLI config reach it.
# `init -backend=false` means a lab's backend block is never configured; `init`
# still downloads providers.
# Before init, a static check fails any lab whose `backend "<type>" {}` block
# references var.* or local.* (Terraform rejects that with "Variables not
# allowed"; -backend=false would otherwise hide it). Nothing is configured.
# Only our grader file (tests/hedronite_grader.tftest.hcl) is run, never a test
# file that ships with the upstream lab.
# The lab type comes from labs.txt: a `fix` lab FAILs until fixed; an `explain`
# lab ships correct, so PASS is expected and FAIL means the config regressed.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
[[ $# -ge 1 ]] || { echo "usage: grade.sh <dest> [lab-prefix ...]" >&2; exit 64; }
dest=$1; shift
grader=tests/hedronite_grader.tftest.hcl
tfhome=$(mktemp -d "${TMPDIR:-/tmp}/grade-home.XXXXXX")
trap 'rm -rf "$tfhome"' EXIT
trap 'rm -rf "$tfhome"; exit 130' INT
trap 'rm -rf "$tfhome"; exit 143' TERM
labtype() { awk -v g="$1" '$1 == g { print $3; exit }' "$here/labs.txt"; }
tf() { env -i HOME="$tfhome" PATH="$PATH" TF_CLI_CONFIG_FILE=/dev/null TF_IN_AUTOMATION=1 ${TF_PLUGIN_CACHE_DIR:+TF_PLUGIN_CACHE_DIR="$TF_PLUGIN_CACHE_DIR"} terraform "$@"; }
# Print file:line for every var./local. reference inside a backend "<type>" { } block.
backend_vars() {
  awk '
    FNR == 1 { inb = 0; depth = 0 }
    { line = $0; sub(/(#|\/\/).*/, "", line) }
    !inb && line ~ /^[[:space:]]*backend[[:space:]]+"[^"]*"[[:space:]]*\{/ { inb = 1; depth = 0 }
    inb {
      if (line ~ /(^|[^A-Za-z0-9_])(var|local)\.[A-Za-z_]/) print FILENAME ":" FNR ": " $0
      o = gsub(/\{/, "{", line); c = gsub(/\}/, "}", line); depth += o - c
      if (depth <= 0) inb = 0
    }' "$1"/*.tf
}
fails=0
for d in "$dest"/*/; do
  name=$(basename "$d"); [[ -f "$d/$grader" ]] || continue
  if [[ $# -gt 0 ]]; then m=0; for p in "$@"; do [[ "$name" == "$p"* ]] && m=1; done; [[ $m == 1 ]] || continue; fi
  type=$(labtype "$name"); type=${type:-fix}
  echo "########## $name [$type]"
  r=PASS
  bad=$(backend_vars "${d%/}")
  if [[ -n "$bad" ]]; then
    r=FAIL
    echo "backend check: FAIL - a backend block cannot use variables or locals (Terraform: \"Variables not allowed\"). Use literals or -backend-config:"
    printf '  %s\n' "${bad//$'\n'/$'\n'  }"
  fi
  if ! (cd "$d" && tf init -backend=false -input=false -lockfile=readonly -no-color >/dev/null && tf test -no-color -filter="$grader"); then r=FAIL; fi
  [[ $r == FAIL ]] && fails=$((fails+1))
  note=""
  if [[ "$type" == explain ]]; then
    if [[ $r == PASS ]]; then note="(expected: ships correct; now write up why it is correct)"
    else note="(regression: an explain lab should pass as shipped)"; fi
  fi
  printf 'RESULT %-36s %-7s %-4s %s\n' "$name" "$type" "$r" "$note"
done
exit "$fails"
