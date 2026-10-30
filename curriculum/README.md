# Curriculum

Graders and helpers for lab material. Upstream lab sources are **not** copied
into this repo; they are referenced through a git submodule.

| path | what |
|---|---|
| `upstream/tfpro-labs` | submodule: [Hedronite/tfpro-labs](https://github.com/Hedronite/tfpro-labs), a fork of [lance0821/tfpro-labs](https://github.com/lance0821/tfpro-labs), pinned to `a96cfa3` |
| `week1/tf/graders/<lab>/hedronite_grader.tftest.hcl` | our `terraform test` grader for each lab, written here (not derived from upstream test files) |
| `week1/tf/labs.txt` | grader → upstream lab dir map, plus lab type (`fix` / `explain`) |
| `week1/tf/stage.sh` | copy labs from the submodule into a workspace and add our grader as `tests/hedronite_grader.tftest.hcl` |
| `week1/tf/grade.sh` | `terraform init -backend=false` + `terraform test` of our grader only, in each staged lab, one `RESULT` line each |
| `week1/tf/logs/` | grader run logs |

## License note

`lance0821/tfpro-labs` has no license file, so all rights stay with its author.
This repo is MIT and therefore must not contain upstream lab files: only our
graders and scripts live here, and the labs are pulled in through the submodule.
Keep it that way until the upstream author grants a license.

## Use

```bash
git submodule update --init                     # fetch the pinned upstream labs
curriculum/week1/tf/stage.sh ~/lab-workspaces/default/week1/tf          # all labs
curriculum/week1/tf/stage.sh ~/lab-workspaces/default/week1/tf 07 09    # some labs
# fix main.tf per the lab README, then:
curriculum/week1/tf/grade.sh ~/lab-workspaces/default/week1/tf 07
```

`stage.sh` never overwrites a lab dir that already exists in the destination
(set `STAGE_FORCE=1` to restage from scratch); it always refreshes our grader.
Some upstream labs ship their own `tests/*.tftest.hcl`; those are left in place
and `grade.sh` runs only `tests/hedronite_grader.tftest.hcl` (`-filter`).
In particular, staged lab 07 still contains upstream's own `tests/basic.tftest.hcl`;
a plain `terraform test` there also runs that file and fails on its
`output.<name>.value` bug, so grade lab 07 with `grade.sh`.

Graders use `mock_provider "aws"`: no cloud credentials and no cloud calls.
`grade.sh` also clears the environment before calling Terraform: only `PATH`,
a throwaway `HOME` (removed on exit), `TF_CLI_CONFIG_FILE=/dev/null`,
`TF_IN_AUTOMATION=1` and, if set, `TF_PLUGIN_CACHE_DIR` pass through. It skips
backend init (`init -backend=false`), and a static pre-check fails any lab whose
`backend "<type>" {}` block references `var.*` or `local.*` (Terraform's
"Variables not allowed"), without ever configuring a backend. `init` still
downloads providers from the Terraform registry. Terraform >= 1.7.

## Lab types

`labs.txt` gives each lab a type; `stage.sh` and `grade.sh` print it.

| type | as shipped | grader | student task |
|---|---|---|---|
| `fix` | broken | FAILs until fixed | fix `main.tf` per the lab README until the grader PASSes |
| `explain` | already correct | PASSes as shipped; it is a regression check | do not change the config; write up why it is correct (which README task each block satisfies and what would break without it) |

Labs 07, 08 and 09 are `explain` labs: their upstream configs already ship in the
correct end state, so a grader cannot turn them red. Their graders stay as
regression checks: a FAIL on 07–09 means the staged config drifted, not that
the student has work left. The graders were also checked against deliberately
broken scratch copies of 08 and 09 and fail them (see `week1/tf/logs/`).

Lab 09's upstream README has a "Starting assumptions" section copied from an S3
lab (bucket versioning, lifecycle, tags). It does not describe the
security-group lab; use its Tasks and Success criteria instead.

## Grader status against the labs as shipped (`a96cfa3`)

| lab | type | as shipped | note |
|---|---|---|---|
| 01–03, 05 | fix | FAIL | intended |
| 04 | fix | FAIL | `grade.sh`'s backend pre-check flags `local.network_state_key` in the `backend "s3"` block; the grader itself checks that remote values are surfaced |
| 06 | fix | PASS | the shipped config already has distinct aliased providers; the grader only checks distinct aliased regions; README tasks 2–3 (child module with `configuration_aliases`) are not graded, review by hand |
| 07 | explain | PASS | validation, precondition and check already present |
| 08 | explain | PASS | IAM role, policy, instance profile and EC2 already wired; broken copy FAILs |
| 09 | explain | PASS | separate rule resources keyed by port already; broken copy FAILs |
