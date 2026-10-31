#!/usr/bin/env bash
# CI gate for lab 01: stage reference/ and starter/ into clean temp copies,
# run grade.sh on each. reference must PASS, starter must FAIL.
#   curriculum/week1/tf/labs/01-lifecycle-cli-broken/ci-gate.sh [log-file]
# Needs terraform >= 1.7 on PATH. NOT a container: runs host terraform via grade.sh (env -i,
# throwaway HOME, no creds). The skill's "clean lab container" needs a docker wrapper (untested). Writes the combined output to ci-gate.log here
# (or the given file). Exit 0 only if both expectations hold.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
tfdir="$(cd "$here/../.." && pwd)"
log="${1:-$here/ci-gate.log}"
lab=01-lifecycle-cli-broken
grader="$tfdir/graders/$lab/hedronite_grader.tftest.hcl"
ok=0
command -v terraform >/dev/null || { echo "ci-gate: terraform not on PATH" >&2; exit 2; }
[[ -f "$grader" ]] || { echo "ci-gate: grader missing: $grader" >&2; exit 2; }
# Tee via process substitution so `ok` is set in THIS shell (a `{ } | tee` pipeline runs the
# block in a subshell; ok=1 was lost and the gate always exited 0).
exec > >(tee "$log") 2>&1
{
  echo "# lab 01 CI gate, $(date '+%Y-%m-%d %H:%M %Z'), $(terraform version | head -1)"
  for variant in reference starter; do
    ws=$(mktemp -d "${TMPDIR:-/tmp}/ci-gate-$variant.XXXXXX")
    mkdir -p "$ws/$lab/tests"
    cp "$here/$variant/"*.tf "$ws/$lab/"
    cp "$grader" "$ws/$lab/tests/hedronite_grader.tftest.hcl"
    echo "================ $variant (clean copy)"
    out=$("$tfdir/grade.sh" "$ws" "$lab" 2>&1); rc=$?
    printf '%s\n' "$out"
    # grade.sh exits 0 with no RESULT line when the lab was not staged: never count that as PASS.
    if ! grep -Eq "^RESULT +$lab +[a-z]+ +(PASS|FAIL)" <<<"$out"; then echo "GATE $variant: no RESULT line"; ok=1; fi
    # The starter must fail on a grader assertion, not on init/provider download (also RESULT FAIL).
    if [[ $variant == starter ]] && ! grep -q 'Test assertion failed' <<<"$out"; then
      echo "GATE starter: FAIL did not come from a grader assertion"; ok=1; fi
    if [[ $variant == reference ]]; then want="rc=0 (PASS)"; [[ $rc -eq 0 ]] || ok=1
    else want="rc!=0 (FAIL)"; [[ $rc -ne 0 ]] || ok=1; fi
    echo "GATE $variant grade.sh rc=$rc, expected $want"
    rm -rf "$ws"
  done
  [[ $ok -eq 0 ]] && echo "GATE OK: reference PASS, starter FAIL" || echo "GATE BROKEN"
}
exit $ok
