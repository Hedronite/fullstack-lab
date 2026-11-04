# Lab 11: import and remote state

Author: Evan Eugene Pincham · Licence: MIT, same as this repository (see `/LICENSE`).
Written for Hedronite from scratch: the scenario, resources, tasks and grader are our own.
It covers exam objectives that public Terraform certification material also covers (importing
resources, refactoring with `moved`, state locking, sharing data through remote state); no
upstream lab text is used.

## Scenario

The edge service's Terraform configuration has just been through three changes at once. A log
bucket was created by hand in the console and the configuration was written to match it. The
release bucket resource was renamed from `releases` to `artifacts`, and the state from the last
apply still records it at the old address. State now lives in an S3 bucket and locks through a
DynamoDB table. Finally, the release bucket's name is typed into this configuration by hand,
although the platform team publishes it as a root output of their own configuration.
`starter/` is valid HCL that gets every one of these wrong.

## Tasks

1. `aws_s3_bucket.legacy_logs` describes a bucket that already exists (`hx-lab11-legacy-logs`).
   Add an `import` block (`to` and `id`) so the next plan adopts it instead of trying to
   create it.
2. Add a `moved` block that records the rename from `aws_s3_bucket.releases` to
   `aws_s3_bucket.artifacts`, so the plan shows a move and not a destroy and create.
3. Switch the `s3` backend to native locking: set `use_lockfile = true` and remove
   `dynamodb_table`.
4. Read the release bucket name from the platform configuration's root output
   `release_bucket_name` (`data.terraform_remote_state.platform`) instead of typing it in.
5. (Not graded.) You edit the `bucket` argument of the `backend` block to point at a new state
   bucket. In one sentence each: what does `terraform init -migrate-state` do, what does
   `terraform init -reconfigure` do, and which of the two would leave the new bucket empty?

`reference/` is the worked answer. Do not open it until you are done.

## Versions

Terraform `= 1.10.5` and `hashicorp/aws = 6.71.0`, the versions in the lab image
`hedronite/fullstack-lab-tf:1.10.5-aws` (offline mirror `/opt/tf-mirror`). `starter/` and
`reference/` ship the same `.terraform.lock.hcl` as labs 01 and 10, so `init` never resolves
versions over the network.

## Stage and grade

```bash
curriculum/week1/tf/stage.sh ~/lab-workspaces/default/week1/tf 11
# edit ~/lab-workspaces/default/week1/tf/11-import-and-remote-state/{main,versions}.tf
curriculum/week1/tf/grade.sh ~/lab-workspaces/default/week1/tf 11
```

```
RESULT 11-import-and-remote-state           fix     FAIL      # starter as staged
RESULT 11-import-and-remote-state           fix     PASS      # after tasks 1 to 4
```

## What the grader can and cannot see

The grader uses a `mock_provider "aws"`, so no credentials and no cloud calls are involved.
A mock provider cannot import and a test has no prior state, so a plan never shows an `import`,
a `moved` or a `backend` block to the test. `check.sh` therefore checks tasks 1, 2 and 3 on the
text of the `.tf` files: comments are stripped and whitespace is collapsed, so layout does not
matter but a commented-out block does not count. An import or moved block may sit in any `.tf`
file, but a valid answer that uses a different resource address or a different backend layout
can still fail those three checks. Task 4 is graded by the test itself: `override_data`
stands in for the platform team's state snapshot, and the artifacts bucket must take its name
from `data.terraform_remote_state.platform.outputs.release_bucket_name`. An `override_resource`
for the imported bucket lets a correct `import` block pass a test that runs on mock providers.

## CI gate

`check.sh` (POSIX sh, lab root) is the checker, run from `starter/` or `reference/` exactly like
labs 01 and 10 (mktemp work dir, `env -i`, `init -lockfile=readonly`, `terraform test`). Its
embedded grader is a byte copy of `graders/11-import-and-remote-state/hedronite_grader.tftest.hcl`.

    ci_gate.py --runner docker --image hedronite/fullstack-lab-tf:1.10.5-aws curriculum/week1/tf/labs/11-import-and-remote-state

`sh ./ci-gate.sh [--write-committed-log] [log-file]` is the host/in-image equivalent (needs the
`graders/` directory two levels up, as in this repository).
