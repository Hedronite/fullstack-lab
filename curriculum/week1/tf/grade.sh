#!/usr/bin/env bash
# Run our graders against staged labs: init + test in each, one RESULT line per lab.
#   curriculum/week1/tf/grade.sh <dest> [lab-prefix ...]
# Uses `terraform` from PATH (>= 1.7). Graders use mock providers. Terraform runs
# with a cleared environment (only HOME, PATH and TF_PLUGIN_CACHE_DIR are passed),
# so no cloud credentials reach it, and with `init -backend=false`, so a lab's
# backend block is never initialised. `init` still downloads providers.
# Only our grader file (tests/hedronite_grader.tftest.hcl) is run, never a test
# file that ships with the upstream lab.
# The lab type comes from labs.txt: a `fix` lab FAILs until fixed; an `explain`
# lab ships correct, so PASS is expected and FAIL means the config regressed.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
[[ $# -ge 1 ]] || { echo "usage: grade.sh <dest> [lab-prefix ...]" >&2; exit 64; }
dest=$1; shift
grader=tests/hedronite_grader.tftest.hcl
labtype() { awk -v g="$1" '$1 == g { print $3; exit }' "$here/labs.txt"; }
tf() { env -i HOME="$HOME" PATH="$PATH" ${TF_PLUGIN_CACHE_DIR:+TF_PLUGIN_CACHE_DIR="$TF_PLUGIN_CACHE_DIR"} TF_IN_AUTOMATION=1 terraform "$@"; }
fails=0
for d in "$dest"/*/; do
  name=$(basename "$d"); [[ -f "$d/$grader" ]] || continue
  if [[ $# -gt 0 ]]; then m=0; for p in "$@"; do [[ "$name" == "$p"* ]] && m=1; done; [[ $m == 1 ]] || continue; fi
  type=$(labtype "$name"); type=${type:-fix}
  echo "########## $name [$type]"
  if (cd "$d" && tf init -backend=false -input=false -no-color >/dev/null && tf test -no-color -filter="$grader"); then r=PASS; else r=FAIL; fails=$((fails+1)); fi
  note=""
  if [[ "$type" == explain ]]; then
    if [[ $r == PASS ]]; then note="(expected: ships correct; now write up why it is correct)"
    else note="(regression: an explain lab should pass as shipped)"; fi
  fi
  printf 'RESULT %-36s %-7s %-4s %s\n' "$name" "$type" "$r" "$note"
done
exit "$fails"
