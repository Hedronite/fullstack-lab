#!/bin/sh
# Lab 16 (edge rollout and service) checker, POSIX sh. Run it from a starter/ or reference/ tree
# (scripts/ci_gate.py copies it next to the three manifests and runs `sh check.sh`).
# Static only: it parses deployment.yaml, service.yaml and hpa.yaml with Nushell (`from yaml`) and
# never calls kubectl or a cluster, so nothing is created, changed or read. It never writes into the
# tree: the Nushell script goes into a mktemp dir removed by a trap, and nu runs through `env -i`
# with only PATH, LANG and a throwaway HOME.
# Prints one `Task n:` line per failed check, then `RESULT 16-edge-rollout-and-service fix PASS|FAIL`.
# Exit 0 PASS, 1 FAIL, 3 setup problem (no nu, a missing or unparseable file): no RESULT line, so a
# crash never counts as the expected starter FAIL.
set -u
lab=16-edge-rollout-and-service
src=$(pwd)
command -v nu >/dev/null || { echo "check.sh: nu (Nushell) not on PATH" >&2; exit 3; }
for f in deployment.yaml service.yaml hpa.yaml; do
  [ -f "$src/$f" ] || { echo "check.sh: $f missing in $src" >&2; exit 3; }
done
work=$(mktemp -d "${TMPDIR:-/tmp}/hx-check.XXXXXX") || exit 3
trap 'rm -rf "$work"' EXIT
trap 'rm -rf "$work"; exit 130' INT
trap 'rm -rf "$work"; exit 143' TERM
mkdir -p "$work/home" || exit 3
cat > "$work/check.nu" <<'HEDRONITE_NU_EOF'
# Hedronite lab 16 checker (Nushell). Reads three manifests from the current directory.
let dep = (open --raw deployment.yaml | from yaml)
let svc = (open --raw service.yaml | from yaml)
let hpa = (open --raw hpa.yaml | from yaml)

let tpl = ($dep.spec?.template? | default {})
let labels = ($tpl.metadata?.labels? | default {})
let c = ($tpl.spec?.containers? | default [] | get -o 0 | default {})
let sel = ($svc.spec?.selector? | default {})
let ports = ($c.ports? | default [])
let tp = ($svc.spec?.ports? | default [] | get -o 0 | default {} | get -o targetPort)
let mu = ($dep.spec?.strategy?.rollingUpdate?.maxUnavailable? | default "unset" | into string)
let ms = ($dep.spec?.strategy?.rollingUpdate?.maxSurge? | default "unset" | into string)
let image = ($c.image? | default "")
let metrics = ($hpa.spec?.metrics? | default [])
let hmin = ($hpa.spec?.minReplicas? | default 1)
let hmax = ($hpa.spec?.maxReplicas? | default 1)

let checks = [
  {ok: (($sel | columns | length) > 0 and ($sel | transpose k v | all {|r| ($labels | get -o $r.k) == $r.v }))
   msg: "Task 1: the Service selector does not match the Pod template labels, so the Service would have no endpoints."}
  {ok: ($tp != null and ($ports | any {|p| ($p.containerPort? == $tp) or ($p.name? == $tp) }))
   msg: "Task 1: the Service targetPort is neither a containerPort nor a named port of the container."}
  {ok: (($dep.spec?.strategy?.type? | default "RollingUpdate") == "RollingUpdate" and $mu in ["0" "0%"] and not ($ms in ["unset" "0" "0%"]))
   msg: "Task 2: the Deployment must use a RollingUpdate with maxUnavailable 0 and a non-zero maxSurge, so capacity never drops during a rollout."}
  {ok: (($dep.spec?.progressDeadlineSeconds? | default 600) <= 300)
   msg: "Task 2: progressDeadlineSeconds is longer than 300 seconds, so a stuck rollout is reported far too late."}
  {ok: (($dep.spec?.revisionHistoryLimit? | default 10) >= 2)
   msg: "Task 2: revisionHistoryLimit is below 2, so there is no earlier ReplicaSet to roll back to."}
  {ok: (($image =~ ':[^:/]+$' and not ($image | str ends-with ':latest')) or ($image | str contains '@sha256:'))
   msg: "Task 3: the image is unpinned (no tag, or :latest), so two revisions cannot be told apart and a rollback has nothing exact to return to."}
  {ok: ($c.readinessProbe? != null)
   msg: "Task 3: the container has no readinessProbe, so a new Pod receives traffic before it is ready and a rollout cannot stall on a bad one."}
  {ok: ($c.resources?.requests?.cpu? != null)
   msg: "Task 3: the container has no CPU request, so the HorizontalPodAutoscaler has no utilization to compute."}
  {ok: (($hpa.spec?.scaleTargetRef?.kind? == "Deployment") and ($hpa.spec?.scaleTargetRef?.name? == $dep.metadata?.name?))
   msg: "Task 4: the HorizontalPodAutoscaler does not target this Deployment by kind and name."}
  {ok: ($metrics | any {|m| $m.type? == "Resource" and $m.resource?.name? == "cpu" and $m.resource?.target?.type? == "Utilization" })
   msg: "Task 4: the HorizontalPodAutoscaler has no CPU Utilization metric."}
  {ok: ($hmin >= 2 and $hmax >= $hmin)
   msg: "Task 4: minReplicas must be at least 2 (one Pod is lost to a node drain otherwise) and maxReplicas at least minReplicas."}
]
let failed = ($checks | where not ok | get msg)
$failed | each {|m| print $m } | ignore
if ($failed | is-empty) { exit 0 } else { exit 10 }
HEDRONITE_NU_EOF
env -i PATH="$PATH" LANG="${LANG:-C.UTF-8}" HOME="$work/home" nu --no-config-file "$work/check.nu"
rc=$?
case $rc in
  0) echo "RESULT $lab fix PASS"; exit 0 ;;
  10) echo "RESULT $lab fix FAIL"; exit 1 ;;
  *) echo "check.sh: nu failed with rc=$rc (unparseable manifest?); no verdict" >&2; exit 3 ;;
esac
