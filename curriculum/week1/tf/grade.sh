#!/usr/bin/env bash
# Run our graders against staged labs: one command grades every task of a lab, one
# RESULT line per lab.
#   curriculum/week1/tf/grade.sh <dest> [lab-prefix ...]   every staged lab under <dest>
#   curriculum/week1/tf/grade.sh <staged-lab-dir>           just that lab (e.g. `grade.sh .`)
# Per lab: backend static check, lock check, the terraform test grader, and, when
# graders/<lab>/static.sh exists, that lab's static task checks (tasks a mock plan or
# apply cannot see, such as import blocks or version bounds). Every part always runs;
# the lab PASSes only if all of them pass.
# Uses `terraform` from PATH (>= 1.7). Graders use mock providers. Terraform runs
# with a cleared environment; only these pass through: PATH, LANG, a throwaway HOME
# (mktemp, removed on exit), TF_IN_AUTOMATION=1, TF_CLI_CONFIG_FILE and, if set,
# TF_PLUGIN_CACHE_DIR. No cloud credentials reach it.
# TF_CLI_CONFIG_FILE is $GRADE_TF_CLI_CONFIG if set (point it ONLY at a provider-mirror
# config; a CLI config can carry registry credentials), else a generated mirror-only
# config when /opt/tf-mirror exists (the lab image: grading works with no network),
# else /dev/null (providers download from the registry).
# `init -backend=false` means a lab's backend block is never configured; `init`
# still downloads providers.
# Before init, a static check fails any lab whose `backend "<type>" {}` block
# references var.* or local.* (Terraform rejects that with "Variables not
# allowed"; -backend=false would otherwise hide it). Nothing is configured.
# Only our grader file (tests/hedronite_grader.tftest.hcl) is run, never a test
# file that ships with the upstream lab.
# The lab type comes from labs.txt: a `fix` lab FAILs until fixed; an `explain`
# lab ships correct, so PASS is expected and FAIL means the config regressed.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
[[ $# -ge 1 ]] || { echo "usage: grade.sh <dest> [lab-prefix ...]" >&2; exit 64; }
dest=$1; shift
grader=tests/hedronite_grader.tftest.hcl
tfhome=$(mktemp -d "${TMPDIR:-/tmp}/grade-home.XXXXXX")
trap 'rm -rf "$tfhome"' EXIT
trap 'rm -rf "$tfhome"; exit 130' INT
trap 'rm -rf "$tfhome"; exit 143' TERM
labtype() { awk -v g="$1" '$1 == g { print $3; exit }' "$here/labs.txt"; }
if [[ -n "${GRADE_TF_CLI_CONFIG:-}" ]]; then cfg=$GRADE_TF_CLI_CONFIG
elif [[ -d /opt/tf-mirror ]]; then
  cfg=$tfhome/mirror.tfrc
  printf 'provider_installation {\n  filesystem_mirror {\n    path = "/opt/tf-mirror"\n  }\n}\n' > "$cfg"
else cfg=/dev/null; fi
tf() { env -i HOME="$tfhome" PATH="$PATH" LANG="${LANG:-C.UTF-8}" TF_CLI_CONFIG_FILE="$cfg" TF_IN_AUTOMATION=1 ${TF_PLUGIN_CACHE_DIR:+TF_PLUGIN_CACHE_DIR="$TF_PLUGIN_CACHE_DIR"} terraform "$@"; }
# Run graders/<lab>/static.sh (POSIX sh) in the staged lab, read-only by contract. It
# prints one "Task N: ..." line per unmet task and exits 0 (all met) or 1 (some unmet);
# any other exit is a broken check and fails the lab. It is read from this repo, never
# from the staged tree, so a student cannot edit it.
static_check() {
  local s=$here/graders/$1/static.sh rc
  [[ -f "$s" ]] || return 0
  (cd "$2" && env -i PATH="$PATH" LANG="${LANG:-C.UTF-8}" sh "$s"); rc=$?
  case $rc in
    0) return 0 ;;
    1) echo "static check: FAIL - unmet tasks above"; return 1 ;;
    *) echo "static check: ERROR - graders/$1/static.sh exited $rc"; return 1 ;;
  esac
}
# Print file:line for every var./local. reference inside a backend "<type>" { } block.
backend_vars() {
  awk '
    FNR == 1 { inb = 0; depth = 0 }
    { line = $0; sub(/(#|\/\/).*/, "", line) }
    !inb && line ~ /^[[:space:]]*backend[[:space:]]+"[^"]*"[[:space:]]*\{/ { inb = 1; depth = 0 }
    inb {
      if (line ~ /(^|[^A-Za-z0-9_])(var|local)\.[A-Za-z_]/) print FILENAME ":" FNR ": " $0
      o = gsub(/\{/, "{", line); c = gsub(/\}/, "}", line); depth += o - c
      if (depth <= 0) inb = 0
    }' "$1"/*.tf
}
# Labs that ship a .terraform.lock.hcl and must be graded against it (init -lockfile=readonly).
# A listed lab with no lock file is refused (FAIL), never graded against fresh provider picks.
must_have_lock=" 01-lifecycle-guardrails "
fails=0
if [[ -f "$dest/$grader" ]]; then
  # A single staged lab: grade just it, whatever the prefixes say.
  dirs=("${dest%/}/"); set --
else
  dirs=("$dest"/*/)
fi
for d in "${dirs[@]}"; do
  d=$(cd "$d" && pwd)/
  name=$(basename "$d"); [[ -f "$d/$grader" ]] || continue
  if [[ $# -gt 0 ]]; then m=0; for p in "$@"; do [[ "$name" == "$p"* ]] && m=1; done; [[ $m == 1 ]] || continue; fi
  type=$(labtype "$name"); type=${type:-fix}
  echo "########## $name [$type]"
  r=PASS
  bad=$(backend_vars "${d%/}")
  if [[ -n "$bad" ]]; then
    r=FAIL
    echo "backend check: FAIL - a backend block cannot use variables or locals (Terraform: \"Variables not allowed\"). Use literals or -backend-config:"
    printf '  %s\n' "${bad//$'\n'/$'\n'  }"
  fi
  # Enforce the lock read-only only where the lab ships one (Hedronite lab 01); the
  # submodule labs (02-09) have none, and readonly init would fail them all.
  lockflag=""
  if [[ -f "$d/.terraform.lock.hcl" ]]; then lockflag="-lockfile=readonly"
  elif [[ "$must_have_lock" == *" $name "* ]]; then
    echo "lock check: FAIL - $name must ship .terraform.lock.hcl (graded with -lockfile=readonly); it is missing, refusing to grade"
    fails=$((fails+1)); printf 'RESULT %-36s %-7s %-4s %s\n' "$name" "$type" FAIL "(refused: lock file missing)"; continue
  else
    echo "WARNING: $name has no .terraform.lock.hcl; providers resolve from its version constraints at init"
  fi
  if ! (cd "$d" && tf init -backend=false -input=false ${lockflag:+"$lockflag"} -no-color >/dev/null && tf test -no-color -filter="$grader"); then r=FAIL; fi
  static_check "$name" "$d" || r=FAIL
  [[ $r == FAIL ]] && fails=$((fails+1))
  note=""
  if [[ "$type" == explain ]]; then
    if [[ $r == PASS ]]; then note="(expected: ships correct; now write up why it is correct)"
    else note="(regression: an explain lab should pass as shipped)"; fi
  fi
  printf 'RESULT %-36s %-7s %-4s %s\n' "$name" "$type" "$r" "$note"
done
exit "$fails"
