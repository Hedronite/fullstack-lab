# Lab 13: release ledger guardrails

Author: Evan Eugene Pincham · Licence: MIT, same as this repository (see `/LICENSE`).
Written for Hedronite from scratch: the scenario, resources, tasks and grader are our own.
It covers exam objectives that public Terraform certification material also covers
(resource lifecycle, moved blocks, Terraform version constraints); no upstream lab text is used.

## Scenario

A deploy tool writes its action ledger (what it promoted, restarted and rolled back) to an S3
bucket. The ledger is the evidence for every rollback, so the bucket must never be lost by
accident. `starter/` has the bucket with versioning suspended, an external tagging policy that makes every plan show tag changes, a rename that would replace the running bucket, and a Terraform version constraint that
accepts every release from 0.13 on.

## Tasks

1. (a) Turn versioning on (`status = "Enabled"`). (b) An external tagging policy edits the bucket's tags,
   so every plan shows drift; leave `tags` alone with `lifecycle { ignore_changes = [tags] }`.
2. The bucket used to be `aws_s3_bucket.soak_ledger` and that is the address in the real state.
   Add a `moved` block so Terraform treats the rename as the same object, not a destroy and create.
3. Bound `required_version` to the 1.10 series with a pessimistic constraint (`~> 1.10`).
   Say in one sentence what the lock file records that `required_version` does not.
4. (Not graded.) `lifecycle { prevent_destroy = true }` makes a plan refuse to destroy the
   ledger, but it does not stop someone deleting the resource block. Name one control outside
   the configuration that would. (A test run cannot grade it: the harness's own cleanup would hit it.)

`reference/` is the worked answer. Do not open it until you are done.

## Versions

Terraform `= 1.10.5` and `hashicorp/aws = 6.71.0`, the versions in the lab image
`hedronite/fullstack-lab-tf:1.10.5-aws` (offline mirror `/opt/tf-mirror`). `starter/` and
`reference/` ship the same `.terraform.lock.hcl` as lab 01.

## Stage and grade

```bash
curriculum/week1/tf/stage.sh ~/lab-workspaces/default/week1/tf 13
# edit ~/lab-workspaces/default/week1/tf/13-release-ledger-guardrails/{main,versions}.tf
curriculum/week1/tf/grade.sh ~/lab-workspaces/default/week1/tf 13
```

```
RESULT 13-release-ledger-guardrails fix FAIL     # starter as staged
RESULT 13-release-ledger-guardrails fix PASS     # after tasks 1, 2 and 3
```

## What the grader can and cannot see

The grader uses `mock_provider "aws"`: it applies the configuration against the mock and asserts
the versioning status (task 1a). `lifecycle` settings, the `moved` block and `required_version` are
not observable in a mock apply over a fresh state, so `check.sh` greps `main.tf` for
`ignore_changes = [tags]` (task 1b) and the `moved` block (task 2), and `versions.tf` for
`required_version` (task 3). No credentials and no cloud calls are involved.

## CI gate

    ci_gate.py --runner docker --image hedronite/fullstack-lab-tf:1.10.5-aws curriculum/week1/tf/labs/13-release-ledger-guardrails

`sh ./ci-gate.sh [--write-committed-log] [log-file]` is the host/in-image equivalent (needs the
`graders/` directory two levels up, as in this repository).
