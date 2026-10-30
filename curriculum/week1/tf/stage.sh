#!/usr/bin/env bash
# Stage week-1 terraform labs into a writable workspace: copy each upstream lab
# from the submodule and drop our grader into its tests/ dir.
#   curriculum/week1/tf/stage.sh <dest> [lab-prefix ...]     e.g. stage.sh ~/lab-workspaces/default/week1/tf 07 09
# Existing lab dirs in <dest> are left alone (your work is never overwritten)
# unless STAGE_FORCE=1.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
up="$(cd "$here/../../upstream/tfpro-labs" && pwd)"
[[ $# -ge 1 ]] || { echo "usage: stage.sh <dest> [lab-prefix ...]" >&2; exit 64; }
dest=$1; shift
[[ -d "$up/labs" ]] || { echo "submodule missing: run 'git submodule update --init'" >&2; exit 1; }
mkdir -p "$dest"
want() { [[ $# -le 1 ]] && return 0; local p; for p in "${@:2}"; do [[ "$1" == "$p"* ]] && return 0; done; return 1; }
n=0
while read -r grader lab; do
  [[ -z "$grader" || "$grader" == \#* ]] && continue
  want "$grader" "$@" || continue
  src="$up/$lab"; out="$dest/$grader"
  [[ -d "$src" ]] || { echo "missing upstream lab: $lab" >&2; exit 1; }
  if [[ -e "$out" && "${STAGE_FORCE:-0}" != 1 ]]; then echo "keep   $out"; else
    rm -rf "$out"; mkdir -p "$out"; cp -R "$src/." "$out/"; echo "staged $out"
  fi
  mkdir -p "$out/tests"; cp "$here/graders/$grader/basic.tftest.hcl" "$out/tests/basic.tftest.hcl"
  n=$((n+1))
done < "$here/labs.txt"
[[ $n -gt 0 ]] || { echo "no lab matched: $*" >&2; exit 1; }
