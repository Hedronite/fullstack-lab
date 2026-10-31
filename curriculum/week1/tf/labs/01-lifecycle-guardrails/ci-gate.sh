#!/bin/sh
# CI gate for lab 01 (lifecycle guardrails). POSIX sh: runs on a host or inside
# hedronite/fullstack-lab-tf (no bash). Runs check.sh from reference/ and starter/ (check.sh
# works in its own mktemp dir and never writes into the tree): reference must PASS, starter
# must FAIL on a grader assertion, and the grader embedded in check.sh must match graders/<lab>/.
#   sh ci-gate.sh [--write-committed-log] [log-file]
# Log: the given file, else $CI_GATE_LOG, else stdout only. A normal run never touches the
# committed ci-gate.log; --write-committed-log (explicit) writes it.
# Env: check.sh runs under `env -i` with PATH, LANG, a throwaway HOME, TF_IN_AUTOMATION=1 and,
# if set, CI_GATE_TF_CLI_CONFIG (point it ONLY at a provider-mirror config; a CLI config can
# carry registry credentials). In the lab image check.sh finds /opt/tf-mirror by itself.
# The preferred gate is scripts/ci_gate.py --runner docker --image <local image> <this dir>.
# Exit 0 only if every expectation holds; 1 gate broken; 2 setup error.
set -u
here=$(cd "$(dirname "$0")" && pwd)
tfdir=$(cd "$here/../.." && pwd)
lab=01-lifecycle-guardrails
grader=$tfdir/graders/$lab/hedronite_grader.tftest.hcl
log=${CI_GATE_LOG:-}
if [ "${1:-}" = --write-committed-log ]; then log=$here/ci-gate.log; shift; fi
[ $# -ge 1 ] && log=$1
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
  echo "# lab 01 CI gate, $(date '+%Y-%m-%d %H:%M %Z'), $(env -i PATH="$PATH" HOME="$tmp" terraform version | head -n 1)"
  sed -n "/^cat > tests\/hedronite_grader.tftest.hcl <<'HEDRONITE_GRADER_EOF'\$/,/^HEDRONITE_GRADER_EOF\$/p" "$here/check.sh" \
    | sed '1d;$d' > "$tmp/embedded.hcl"
  if cmp -s "$tmp/embedded.hcl" "$grader"; then echo "GATE grader: check.sh copy matches graders/$lab"
  else echo "GATE grader: check.sh copy DRIFTED from graders/$lab"; ok=1; fi
  for variant in reference starter; do
    echo "================ $variant"
    (cd "$here/$variant" && env -i PATH="$PATH" LANG="${LANG:-C.UTF-8}" HOME="$tmp" TMPDIR="$tmp" \
      ${CI_GATE_TF_CLI_CONFIG:+CI_GATE_TF_CLI_CONFIG="$CI_GATE_TF_CLI_CONFIG"} sh "$here/check.sh") > "$tmp/out" 2>&1
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
[ -n "$log" ] && cp "$tmp/log" "$log"
cat "$tmp/log"
exit "$ok"
