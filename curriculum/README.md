# Curriculum

Graders and helpers for lab material. Upstream lab sources are **not** copied
into this repo; they are referenced through a git submodule.

| path | what |
|---|---|
| `upstream/tfpro-labs` | submodule: [Hedronite/tfpro-labs](https://github.com/Hedronite/tfpro-labs), a fork of [lance0821/tfpro-labs](https://github.com/lance0821/tfpro-labs), pinned to `a96cfa3` |
| `week1/tf/graders/<lab>/basic.tftest.hcl` | our `terraform test` grader for each lab |
| `week1/tf/labs.txt` | grader → upstream lab dir map |
| `week1/tf/stage.sh` | copy labs from the submodule into a workspace and drop the graders into `tests/` |
| `week1/tf/grade.sh` | `terraform init` + `terraform test` in each staged lab, one `RESULT` line each |
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
(set `STAGE_FORCE=1` to restage from scratch); it always refreshes the grader.
Graders use `mock_provider "aws"`: no credentials, no network, no cost. They need
Terraform >= 1.7. Labs are RED as shipped, by design, except as noted below.

## Grader status against the labs as shipped (`a96cfa3`)

| lab | as shipped | note |
|---|---|---|
| 01–05 | FAIL | intended: the lab is broken until the student fixes it (04 fails at init: variables in the backend block) |
| 06 | PASS | the shipped config already has distinct aliased providers; README tasks 2–3 (child module with `configuration_aliases`) are not checkable by the grader |
| 07 | PASS | the shipped config already has the validation, precondition and check the README asks for |
| 08 | PASS | the shipped config is already correctly wired; a deliberately broken copy FAILs |
| 09 | PASS | the shipped config already uses separate rule resources keyed by port; a deliberately broken copy FAILs. Its README "Starting assumptions" section describes a different (S3) lab |
