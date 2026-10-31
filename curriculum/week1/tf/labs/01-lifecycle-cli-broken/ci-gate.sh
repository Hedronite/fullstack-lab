#!/usr/bin/env bash
# CI gate for lab 01: stage reference/ and starter/ into clean temp copies,
# run grade.sh on each. reference must PASS, starter must FAIL.
#   curriculum/week1/tf/labs/01-lifecycle-cli-broken/ci-gate.sh [log-file]
# Needs terraform >= 1.7 on PATH. Writes the combined output to ci-gate.log here
# (or the given file). Exit 0 only if both expectations hold.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
tfdir="$(cd "$here/../.." && pwd)"
log="${1:-$here/ci-gate.log}"
lab=01-lifecycle-cli-broken
grader="$tfdir/graders/$lab/hedronite_grader.tftest.hcl"
ok=0
{
  echo "# lab 01 CI gate, $(date '+%Y-%m-%d %H:%M %Z'), $(terraform version | head -1)"
  for variant in reference starter; do
    ws=$(mktemp -d "${TMPDIR:-/tmp}/ci-gate-$variant.XXXXXX")
    mkdir -p "$ws/$lab/tests"
    cp "$here/$variant/"*.tf "$ws/$lab/"
    cp "$grader" "$ws/$lab/tests/hedronite_grader.tftest.hcl"
    echo "================ $variant (clean copy)"
    "$tfdir/grade.sh" "$ws" "$lab"
    rc=$?
    if [[ $variant == reference ]]; then want="rc=0 (PASS)"; [[ $rc -eq 0 ]] || ok=1
    else want="rc!=0 (FAIL)"; [[ $rc -ne 0 ]] || ok=1; fi
    echo "GATE $variant grade.sh rc=$rc, expected $want"
    rm -rf "$ws"
  done
  [[ $ok -eq 0 ]] && echo "GATE OK: reference PASS, starter FAIL" || echo "GATE BROKEN"
} 2>&1 | tee "$log"
exit $ok
