#!/bin/sh
# Lab 17 (checkpoint job and claim) checker, POSIX sh. Run it from a starter/ or reference/ tree
# (scripts/ci_gate.py copies it next to the three manifests and runs `sh check.sh`).
# Static only: it parses job.yaml, pvc.yaml and storageclass.yaml with Nushell (`from yaml`) and
# never calls kubectl or a cluster, so nothing is created, changed or read. It never writes into the
# tree: the Nushell script goes into a mktemp dir removed by a trap, and nu runs through `env -i`
# with only PATH, LANG and a throwaway HOME.
# Prints one `Task n:` line per failed check, then `RESULT 17-checkpoint-job-and-claim fix PASS|FAIL`.
# Exit 0 PASS, 1 FAIL, 3 setup problem (no nu, a missing or unparseable file): no RESULT line, so a
# crash never counts as the expected starter FAIL.
set -u
lab=17-checkpoint-job-and-claim
src=$(pwd)
command -v nu >/dev/null || { echo "check.sh: nu (Nushell) not on PATH" >&2; exit 3; }
for f in job.yaml pvc.yaml storageclass.yaml; do
  [ -f "$src/$f" ] || { echo "check.sh: $f missing in $src" >&2; exit 3; }
done
work=$(mktemp -d "${TMPDIR:-/tmp}/hx-check.XXXXXX") || exit 3
trap 'rm -rf "$work"' EXIT
trap 'rm -rf "$work"; exit 130' INT
trap 'rm -rf "$work"; exit 143' TERM
mkdir -p "$work/home" || exit 3
cat > "$work/check.nu" <<'HEDRONITE_NU_EOF'
# Hedronite lab 17 checker (Nushell). Reads three manifests from the current directory.
let job = (open --raw job.yaml | from yaml)
let pvc = (open --raw pvc.yaml | from yaml)
let sc = (open --raw storageclass.yaml | from yaml)

let tpl = ($job.spec?.template?.spec? | default {})
let c = ($tpl.containers? | default [] | get -o 0 | default {})
let image = ($c.image? | default "")
let vols = ($tpl.volumes? | default [])
let mounts = ($c.volumeMounts? | default [])
let ckpt = ($vols | where {|v| $v.persistentVolumeClaim? != null } | get -o 0 | default {})
let rules = ($job.spec?.podFailurePolicy?.rules? | default [])
let failjob = ($rules | where {|r| $r.action? == "FailJob" and $r.onExitCodes? != null })
let bl = ($job.spec?.backoffLimit? | default 6)
let dl = ($job.spec?.activeDeadlineSeconds? | default 0)
let pvc_class = ($pvc.spec?.storageClassName? | default "")

let checks = [
  {ok: (($sc.reclaimPolicy? | default "Delete") == "Retain")
   msg: "Task 1: the StorageClass reclaimPolicy is not Retain (unset means Delete), so deleting the claim would delete the checkpoints."}
  {ok: ($pvc_class == ($sc.metadata?.name? | default "-"))
   msg: "Task 1: the claim storageClassName does not name the StorageClass in storageclass.yaml, so it would not be provisioned from it."}
  {ok: (($pvc.spec?.accessModes? | default []) == ["ReadWriteOncePod"])
   msg: "Task 2: the claim must request exactly ReadWriteOncePod, so only one Pod in the cluster can write the checkpoints."}
  {ok: (($ckpt.persistentVolumeClaim?.claimName? | default "") == ($pvc.metadata?.name? | default "-") and ($mounts | any {|m| $m.name? == $ckpt.name? }))
   msg: "Task 2: the Job does not mount the claim: a volume must use persistentVolumeClaim with the claim's name and the container must mount it (an emptyDir is deleted with the Pod)."}
  {ok: (($tpl.restartPolicy? | default "Always") == "Never")
   msg: "Task 3: restartPolicy must be Never, so a failed Pod is replaced and its exit code is seen by the Job controller."}
  {ok: ($bl >= 1 and $bl <= 6)
   msg: "Task 3: backoffLimit must be between 1 and 6 (the retry budget), not unlimited-looking."}
  {ok: ($dl > 0 and $dl <= 7200)
   msg: "Task 3: activeDeadlineSeconds must be set to 7200 or less, so the whole Job has a time budget."}
  {ok: ($failjob | any {|r| $r.onExitCodes?.operator? == "In" and (($r.onExitCodes?.values? | default []) | any {|v| $v == 78 }) })
   msg: "Task 4: no podFailurePolicy rule with action FailJob on exit code 78 (operator In), so a configuration error would burn the whole retry budget."}
  {ok: ($rules | any {|r| $r.action? == "Ignore" and ($r.onPodConditions? | default [] | any {|p| $p.type? == "DisruptionTarget" }) })
   msg: "Task 4: no podFailurePolicy rule that Ignores a DisruptionTarget condition, so a node drain would count against the retry budget."}
  {ok: (($image =~ ':[^:/]+$' and not ($image | str ends-with ':latest')) or ($image | str contains '@sha256:'))
   msg: "Task 5: the image is unpinned (no tag, or :latest), so a retry could run a different program than the first attempt."}
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
