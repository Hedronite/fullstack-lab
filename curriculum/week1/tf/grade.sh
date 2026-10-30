#!/usr/bin/env bash
# Run graders against staged labs: init + test in each, print one RESULT line per lab.
#   curriculum/week1/tf/grade.sh <dest> [lab-prefix ...]
# Uses `terraform` from PATH (>= 1.7). Graders use mock providers: no credentials.
set -uo pipefail
[[ $# -ge 1 ]] || { echo "usage: grade.sh <dest> [lab-prefix ...]" >&2; exit 64; }
dest=$1; shift
fails=0
for d in "$dest"/*/; do
  name=$(basename "$d"); [[ -f "$d/tests/basic.tftest.hcl" ]] || continue
  if [[ $# -gt 0 ]]; then m=0; for p in "$@"; do [[ "$name" == "$p"* ]] && m=1; done; [[ $m == 1 ]] || continue; fi
  echo "########## $name"
  if (cd "$d" && terraform init -input=false -no-color >/dev/null && terraform test -no-color); then r=PASS; else r=FAIL; fails=$((fails+1)); fi
  printf 'RESULT %-36s %s\n' "$name" "$r"
done
exit "$fails"
