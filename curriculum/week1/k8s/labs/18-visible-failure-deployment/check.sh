#!/bin/sh
# Lab 18 (visible failure deployment) checker, POSIX sh. Run it from a starter/ or reference/ tree
# (scripts/ci_gate.py copies it next to deployment.yaml and runs `sh check.sh`).
# Static only: it parses deployment.yaml with Nushell (`from yaml`) and never calls kubectl or a
# cluster. It never writes into the tree: the Nushell script goes into a mktemp dir removed by a
# trap, and nu runs through `env -i` with only PATH, LANG and a throwaway HOME.
# Prints one `Task n:` line per failed check, then `RESULT 18-visible-failure-deployment fix PASS|FAIL`.
# Exit 0 PASS, 1 FAIL, 3 setup problem (no nu, a missing or unparseable file): no RESULT line.
set -u
lab=18-visible-failure-deployment
src=$(pwd)
command -v nu >/dev/null || { echo "check.sh: nu (Nushell) not on PATH" >&2; exit 3; }
[ -f "$src/deployment.yaml" ] || { echo "check.sh: deployment.yaml missing in $src" >&2; exit 3; }
work=$(mktemp -d "${TMPDIR:-/tmp}/hx-check.XXXXXX") || exit 3
trap 'rm -rf "$work"' EXIT
trap 'rm -rf "$work"; exit 130' INT
trap 'rm -rf "$work"; exit 143' TERM
mkdir -p "$work/home" || exit 3
cat > "$work/check.nu" <<'HEDRONITE_NU_EOF'
# Hedronite lab 18 checker (Nushell). Reads deployment.yaml from the current directory.
let d = (open --raw deployment.yaml | from yaml)
let tpl = ($d.spec?.template?.spec? | default {})
let c = ($tpl.containers? | default [] | get -o 0 | default {})
let image = ($c.image? | default "")
let args = ($c.args? | default [])
let sc = ($c.securityContext? | default {})
let mounts = ($c.volumeMounts? | default [])
let vols = ($tpl.volumes? | default [])
let rev = ($d.spec?.revisionHistoryLimit? | default 10)
let pd = ($d.spec?.progressDeadlineSeconds? | default 600)
let tmp_ok = ($mounts | any {|m| $m.mountPath? == "/tmp" and ($vols | any {|v| $v.name? == $m.name? and $v.emptyDir? != null }) })

let checks = [
  {ok: (($c.terminationMessagePolicy? | default "File") == "FallbackToLogsOnError")
   msg: "Task 1: terminationMessagePolicy is not FallbackToLogsOnError, so a crash with an empty termination message shows operators nothing."}
  {ok: (not ($args | any {|a| ($a | into string) =~ '^--log-file' }) and not ($mounts | any {|m| ($m.mountPath? | default "" | str starts-with "/var/log") }))
   msg: "Task 2: the app writes its log to a file in the container; log to stdout and stderr so kubectl logs and --previous can show it."}
  {ok: ($rev >= 5)
   msg: "Task 3: revisionHistoryLimit must be 5 or more, so earlier ReplicaSets stay available as history and for rollback."}
  {ok: ($pd > 0 and $pd <= 600)
   msg: "Task 3: progressDeadlineSeconds must be 600 or less, so a stuck rollout is reported as failed in a bounded time."}
  {ok: ($c.readinessProbe? != null and $c.livenessProbe? != null and (($c.livenessProbe?.failureThreshold? | default 3) >= 3))
   msg: "Task 4: the container needs both a readinessProbe and a livenessProbe (failureThreshold 3 or more), so an unhealthy Pod is taken out of service and restarted visibly."}
  {ok: (($sc.readOnlyRootFilesystem? | default false) == true and $tmp_ok)
   msg: "Task 5: set readOnlyRootFilesystem: true and give the app a writable emptyDir mounted at /tmp."}
  {ok: (($sc.privileged? | default false) == false and ($sc.allowPrivilegeEscalation? | default true) == false)
   msg: "Task 5: the container must not be privileged and must set allowPrivilegeEscalation: false."}
  {ok: (($image =~ ':[^:/]+$' and not ($image | str ends-with ':latest')) or ($image | str contains '@sha256:'))
   msg: "Task 6: the image is unpinned (no tag, or :latest), so a restart could run a different program than the one that failed."}
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
