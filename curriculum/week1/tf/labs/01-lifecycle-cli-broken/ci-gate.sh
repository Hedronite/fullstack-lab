#!/bin/sh
# CI gate for lab 01 (POSIX sh: runs on a host or inside hedronite/fullstack-lab-tf, which has
# no bash). Copies reference/ and starter/ into clean temp dirs with the root check.sh and runs
# `sh check.sh` in each. reference must PASS, starter must FAIL on a grader assertion.
#   curriculum/week1/tf/labs/01-lifecycle-cli-broken/ci-gate.sh [log-file]
# Also fails if the grader embedded in check.sh drifts from graders/<lab>/.
# Env for terraform is cleared: PATH, a throwaway HOME, TF_IN_AUTOMATION=1,
# TF_CLI_CONFIG_FILE=${CI_GATE_TF_CLI_CONFIG:-/dev/null} and, if set, TF_PLUGIN_CACHE_DIR.
# In the lab image pass CI_GATE_TF_CLI_CONFIG=/root/.terraformrc (its offline provider mirror).
# The preferred gate is scripts/ci_gate.py --runner docker --image <local image> <this dir>.
# Writes the combined output to the given log file (default: ci-gate.log here).
# Exit 0 only if every expectation holds; 2 on a setup error.
set -u
here=$(cd "$(dirname "$0")" && pwd)
tfdir=$(cd "$here/../.." && pwd)
log=${1:-$here/ci-gate.log}
lab=01-lifecycle-cli-broken
grader=$tfdir/graders/$lab/hedronite_grader.tftest.hcl
command -v terraform >/dev/null || { echo "ci-gate: terraform not on PATH" >&2; exit 2; }
[ -f "$grader" ] || { echo "ci-gate: grader missing: $grader" >&2; exit 2; }
[ -f "$here/check.sh" ] || { echo "ci-gate: check.sh missing in $here" >&2; exit 2; }
tmp=$(mktemp -d "${TMPDIR:-/tmp}/ci-gate.XXXXXX") || exit 2
trap 'rm -rf "$tmp"' EXIT
trap 'rm -rf "$tmp"; exit 130' INT
trap 'rm -rf "$tmp"; exit 143' TERM
ok=0
# A { } group with a redirect runs in this shell, so ok survives (no pipeline subshell).
{
  echo "# lab 01 CI gate, $(date '+%Y-%m-%d %H:%M %Z'), $(terraform version | head -n 1)"
  sed -n "/^cat > tests\/hedronite_grader.tftest.hcl <<'HEDRONITE_GRADER_EOF'\$/,/^HEDRONITE_GRADER_EOF\$/p" "$here/check.sh" \
    | sed '1d;$d' > "$tmp/embedded.hcl"
  if cmp -s "$tmp/embedded.hcl" "$grader"; then echo "GATE grader: check.sh copy matches graders/$lab"
  else echo "GATE grader: check.sh copy DRIFTED from graders/$lab"; ok=1; fi
  for variant in reference starter; do
    ws=$tmp/$variant; mkdir -p "$ws" "$tmp/home-$variant"
    cp "$here/$variant/"*.tf "$ws/" && cp "$here/check.sh" "$ws/check.sh"
    echo "================ $variant (clean copy)"
    (cd "$ws" && env -i PATH="$PATH" HOME="$tmp/home-$variant" TF_IN_AUTOMATION=1 \
      TF_CLI_CONFIG_FILE="${CI_GATE_TF_CLI_CONFIG:-/dev/null}" \
      ${TF_PLUGIN_CACHE_DIR:+TF_PLUGIN_CACHE_DIR="$TF_PLUGIN_CACHE_DIR"} sh check.sh) > "$tmp/out" 2>&1
    rc=$?
    cat "$tmp/out"
    if ! grep -Eq "^RESULT +$lab +[a-z]+ +(PASS|FAIL)" "$tmp/out"; then echo "GATE $variant: no RESULT line"; ok=1; fi
    if [ "$variant" = starter ] && ! grep -q 'Test assertion failed' "$tmp/out"; then
      echo "GATE starter: FAIL did not come from a grader assertion"; ok=1; fi
    if [ "$variant" = reference ]; then want="rc=0 (PASS)"; [ "$rc" -eq 0 ] || ok=1
    else want="rc!=0 (FAIL)"; [ "$rc" -ne 0 ] || ok=1; fi
    echo "GATE $variant check.sh rc=$rc, expected $want"
  done
  if [ "$ok" -eq 0 ]; then echo "GATE OK: reference PASS, starter FAIL"; else echo "GATE BROKEN"; fi
} > "$tmp/log" 2>&1
cp "$tmp/log" "$log"
cat "$tmp/log"
exit "$ok"
