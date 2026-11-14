#!/bin/sh
# CI gate for lab 17 (checkpoint job and claim). POSIX sh; runs on a host with Nushell or inside
# hedronite/fullstack-lab-ops (nu 0.116). Runs check.sh from reference/ and starter/ (check.sh
# never writes into the tree): reference must PASS, starter must FAIL with Task lines, and the ten
# listed single-edit mutants of the reference must each FAIL.
#   sh ci-gate.sh [log-file]
# The preferred gate is scripts/ci_gate.py --runner docker --image <local image> <this dir>.
# Exit 0 only if every expectation holds; 1 gate broken; 2 setup error.
set -u
here=$(cd "$(dirname "$0")" && pwd)
lab=17-checkpoint-job-and-claim
log=${1:-${CI_GATE_LOG:-}}
command -v nu >/dev/null || { echo "ci-gate: nu not on PATH" >&2; exit 2; }
[ -f "$here/check.sh" ] || { echo "ci-gate: check.sh missing" >&2; exit 2; }
tmp=$(mktemp -d "${TMPDIR:-/tmp}/ci-gate.XXXXXX") || exit 2
trap 'rm -rf "$tmp"' EXIT
ok=0
{
  echo "# lab 17 CI gate, $(date '+%Y-%m-%d %H:%M %Z'), nu $(nu --version)"
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
storageclass.yaml|reclaimPolicy: Retain|reclaimPolicy: Delete
pvc.yaml|storageClassName: checkpoints|storageClassName: scratch
pvc.yaml|- ReadWriteOncePod|- ReadWriteMany
job.yaml|claimName: trainjob-ckpt|claimName: other-claim
job.yaml|restartPolicy: Never|restartPolicy: OnFailure
job.yaml|backoffLimit: 4|backoffLimit: 50
job.yaml|activeDeadlineSeconds: 3600|activeDeadlineSeconds: 86400
job.yaml|values: \[78\]|values: [42]
job.yaml|type: DisruptionTarget|type: Ready
job.yaml|trainjob:1.2.0|trainjob:latest
MUTANTS
  if [ "$ok" -eq 0 ]; then echo "GATE OK: reference PASS, starter FAIL, $n mutants FAIL"; else echo "GATE BROKEN"; fi
} > "$tmp/log" 2>&1
[ -n "$log" ] && cp "$tmp/log" "$log"
cat "$tmp/log"
exit "$ok"
