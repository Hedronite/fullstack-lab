#!/bin/sh
# Grade staged labs with one command: every task of a lab, one RESULT line per lab.
#   curriculum/week1/tf/grade.sh <dest> [lab-prefix ...]   every staged lab under <dest>
#   curriculum/week1/tf/grade.sh <staged-lab-dir>           just that lab (e.g. `grade.sh .`)
# POSIX sh: runs under dash, busybox sh (the lab image has no bash) and bash.
#
# Per lab, in order, and every step always runs:
#   1. backend check: fails any `backend "<type>" {}` block that references var.* or
#      local.* (Terraform rejects that with "Variables not allowed"; -backend=false
#      would otherwise hide it). Nothing is configured.
#   2. lock check: a lab that must ship .terraform.lock.hcl is refused without one;
#      a lab that ships one is initialised with -lockfile=readonly.
#   3. the terraform test grader (tests/hedronite_grader.tftest.hcl only, never a test
#      file that ships with an upstream lab), against mock providers.
#   4. the lab's own check.sh, for a Hedronite-authored lab (labs.txt `local:<dir>`;
#      check.sh sits in the folder above starter/). It checks tasks a mock apply cannot
#      see, such as import blocks and version bounds. Only its "Task ..." and "check.sh:"
#      lines are shown, as detail; its own RESULT line is dropped. Exit 3 (setup or init
#      failure) counts as FAIL.
#      GRADE_SKIP_CHECK=1 skips this step (grader only, the earlier behaviour).
# The lab PASSes only if every step passes. The last line per lab is its verdict:
#   RESULT <lab> <type> PASS|FAIL [note]
# Exit status: the number of labs that failed (0 = all passed); 64 on a usage error.
#
# Uses `terraform` from PATH (>= 1.7). Terraform runs with a cleared environment; only
# PATH, LANG, a throwaway HOME (mktemp, removed on exit), TF_IN_AUTOMATION=1,
# TF_CLI_CONFIG_FILE and, if set, TF_PLUGIN_CACHE_DIR pass through. No cloud
# credentials reach it. TF_CLI_CONFIG_FILE is $GRADE_TF_CLI_CONFIG if set (point it
# ONLY at a provider-mirror config; a CLI config can carry registry credentials), else
# a generated mirror-only config when /opt/tf-mirror exists (the lab image: no network
# needed), else /dev/null (providers download from the registry). check.sh gets the
# same choice through CI_GATE_TF_CLI_CONFIG.
# The lab type comes from labs.txt: a `fix` lab FAILs until fixed; an `explain` lab
# ships correct, so PASS is expected and FAIL means the config regressed.
set -u
here=$(cd "$(dirname "$0")" && pwd)
[ $# -ge 1 ] || { echo "usage: grade.sh <dest> [lab-prefix ...] | grade.sh <staged-lab-dir>" >&2; exit 64; }
dest=$1; shift
grader=tests/hedronite_grader.tftest.hcl
tfhome=$(mktemp -d "${TMPDIR:-/tmp}/grade-home.XXXXXX") || exit 70
trap 'rm -rf "$tfhome"' EXIT
trap 'rm -rf "$tfhome"; exit 130' INT
trap 'rm -rf "$tfhome"; exit 143' TERM
if [ -n "${GRADE_TF_CLI_CONFIG:-}" ]; then cfg=$GRADE_TF_CLI_CONFIG
elif [ -d /opt/tf-mirror ]; then
  cfg=$tfhome/mirror.tfrc
  printf 'provider_installation {\n  filesystem_mirror {\n    path = "/opt/tf-mirror"\n  }\n}\n' > "$cfg"
else cfg=/dev/null; fi

labfield() { awk -v g="$1" -v f="$2" '$1 == g { print $f; exit }' "$here/labs.txt"; }
tf() {
  env -i HOME="$tfhome" PATH="$PATH" LANG="${LANG:-C.UTF-8}" TF_CLI_CONFIG_FILE="$cfg" TF_IN_AUTOMATION=1 \
    ${TF_PLUGIN_CACHE_DIR:+"TF_PLUGIN_CACHE_DIR=$TF_PLUGIN_CACHE_DIR"} terraform "$@"
}
# Path of the lab's own check.sh for a local:<dir> lab (the dir above starter/), or nothing.
labcheck() {
  _src=$(labfield "$1" 2)
  case $_src in local:*) ;; *) return 0 ;; esac
  _dir=$here/${_src#local:}
  [ "$(basename "$_dir")" = starter ] && _dir=$(dirname "$_dir")
  [ -f "$_dir/check.sh" ] && printf '%s\n' "$_dir/check.sh"
  return 0
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

grade_one() {
  d=$(cd "$1" && pwd) || return 0
  name=$(basename "$d")
  type=$(labfield "$name" 3); type=${type:-fix}
  echo "########## $name [$type]"
  r=PASS
  bad=$(backend_vars "$d")
  if [ -n "$bad" ]; then
    r=FAIL
    echo "backend check: FAIL - a backend block cannot use variables or locals (Terraform: \"Variables not allowed\"). Use literals or -backend-config:"
    printf '%s\n' "$bad" | sed 's/^/  /'
  fi
  lockflag=""
  if [ -f "$d/.terraform.lock.hcl" ]; then lockflag="-lockfile=readonly"
  else
    case $must_have_lock in
      *" $name "*)
        echo "lock check: FAIL - $name must ship .terraform.lock.hcl (graded with -lockfile=readonly); it is missing, refusing to grade"
        fails=$((fails + 1))
        printf 'RESULT %-36s %-7s %-4s %s\n' "$name" "$type" FAIL "(refused: lock file missing)"
        return 0 ;;
    esac
    echo "WARNING: $name has no .terraform.lock.hcl; providers resolve from its version constraints at init"
  fi
  if ! (cd "$d" && tf init -backend=false -input=false ${lockflag:+"$lockflag"} -no-color >/dev/null && tf test -no-color -filter="$grader"); then
    r=FAIL
  fi
  chk=""
  [ "${GRADE_SKIP_CHECK:-0}" = 1 ] || chk=$(labcheck "$name")
  if [ -n "$chk" ]; then
    echo "check.sh: ${chk#"$here"/}"
    # check.sh copies the .tf files into its own temp dir and never writes into the staged lab.
    out=$(cd "$d" && env ${cfg:+"CI_GATE_TF_CLI_CONFIG=$cfg"} sh "$chk" 2>&1); rc=$?
    # Detail only: its task lines and its own messages. The grader output it repeats was
    # already shown in step 3, and its RESULT line is replaced by the verdict below.
    printf '%s\n' "$out" | grep -E '^(Task |check\.sh:)' | sed 's/^/  /'
    if [ "$rc" -ne 0 ]; then
      r=FAIL
      [ "$rc" -eq 3 ] && echo "check.sh: setup/init failure (exit 3), counted as FAIL"
    fi
  fi
  [ "$r" = FAIL ] && fails=$((fails + 1))
  note=""
  if [ "$type" = explain ]; then
    if [ "$r" = PASS ]; then note="(expected: ships correct; now write up why it is correct)"
    else note="(regression: an explain lab should pass as shipped)"; fi
  fi
  printf 'RESULT %-36s %-7s %-4s %s\n' "$name" "$type" "$r" "$note"
}

if [ -f "$dest/$grader" ]; then
  grade_one "$dest"            # a single staged lab, whatever the prefixes say
else
  for d0 in "$dest"/*/; do
    [ -f "$d0$grader" ] || continue
    if [ $# -gt 0 ]; then
      m=0; n0=$(basename "$d0")
      for p in "$@"; do case $n0 in "$p"*) m=1 ;; esac; done
      [ "$m" = 1 ] || continue
    fi
    grade_one "$d0"
  done
fi
exit "$fails"
