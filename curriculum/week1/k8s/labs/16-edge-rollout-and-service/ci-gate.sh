#!/bin/sh
# CI gate for lab 16 (edge rollout and service). POSIX sh; runs on a host with Nushell or inside
# hedronite/fullstack-lab-ops (nu 0.116). Runs check.sh from reference/ and starter/ (check.sh
# never writes into the tree): reference must PASS, starter must FAIL with Task lines, and the six
# listed single-edit mutants of the reference must each FAIL.
#   sh ci-gate.sh [log-file]
# The preferred gate is scripts/ci_gate.py --runner docker --image <local image> <this dir>.
# Exit 0 only if every expectation holds; 1 gate broken; 2 setup error.
set -u
here=$(cd "$(dirname "$0")" && pwd)
lab=16-edge-rollout-and-service
log=${1:-${CI_GATE_LOG:-}}
command -v nu >/dev/null || { echo "ci-gate: nu not on PATH" >&2; exit 2; }
[ -f "$here/check.sh" ] || { echo "ci-gate: check.sh missing" >&2; exit 2; }
tmp=$(mktemp -d "${TMPDIR:-/tmp}/ci-gate.XXXXXX") || exit 2
trap 'rm -rf "$tmp"' EXIT
ok=0
{
  echo "# lab 16 CI gate, $(date '+%Y-%m-%d %H:%M %Z'), nu $(nu --version)"
  for variant in reference starter; do
    echo "================ $variant"
    (cd "$here/$variant" && TMPDIR=$tmp sh "$here/check.sh") > "$tmp/out" 2>&1; rc=$?
    cat "$tmp/out"
    grep -Eq "^RESULT +$lab +fix +(PASS|FAIL)" "$tmp/out" || { echo "GATE $variant: no RESULT line"; ok=1; }
    if [ "$variant" = reference ]; then [ "$rc" -eq 0 ] || ok=1
    else [ "$rc" -eq 1 ] && grep -q '^Task ' "$tmp/out" || ok=1; fi
    echo "GATE $variant check.sh rc=$rc"
  done
  n=0
  while IFS='|' read -r file from to; do
    [ -n "$file" ] || continue
    n=$((n+1)); m=$tmp/m$n; rm -rf "$m"; cp -R "$here/reference" "$m"
    sed "s|$from|$to|" "$m/$file" > "$m/$file.new" && mv "$m/$file.new" "$m/$file"
    cmp -s "$m/$file" "$here/reference/$file" && { echo "MUTANT $n ($file: $from): sed changed nothing"; ok=1; continue; }
    (cd "$m" && TMPDIR=$tmp sh "$here/check.sh") > "$tmp/mout" 2>&1; mrc=$?
    if [ "$mrc" -eq 1 ] && grep -q "^RESULT $lab fix FAIL" "$tmp/mout"; then echo "MUTANT $n ($file: $from -> $to): FAIL as required"
    else echo "MUTANT $n ($file: $from -> $to): rc=$mrc, expected FAIL"; ok=1; fi
  done <<'MUTANTS'
service.yaml|app: edge-api|app: edgeapi
service.yaml|targetPort: http|targetPort: 8081
deployment.yaml|maxUnavailable: 0|maxUnavailable: 1
deployment.yaml|progressDeadlineSeconds: 120|progressDeadlineSeconds: 3600
deployment.yaml|revisionHistoryLimit: 5|revisionHistoryLimit: 0
deployment.yaml|api:2.4.1|api:latest
deployment.yaml|readinessProbe:|livenessProbe:
deployment.yaml|cpu: 250m|ephemeral-storage: 1Gi
hpa.yaml|name: edge-api$|name: edge-apy
hpa.yaml|minReplicas: 3|minReplicas: 1
MUTANTS
  if [ "$ok" -eq 0 ]; then echo "GATE OK: reference PASS, starter FAIL, $n mutants FAIL"; else echo "GATE BROKEN"; fi
} > "$tmp/log" 2>&1
[ -n "$log" ] && cp "$tmp/log" "$log"
cat "$tmp/log"
exit "$ok"
