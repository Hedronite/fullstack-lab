# Lab 20: ledger archive, moved block and remote state

Simulated, offline and free: the grader runs against `mock_provider "aws"` and replaces the
remote-state read with `override_data`, so there are no credentials, no cloud calls and no cost.
Objectives: TFA-1 (refactor state with a `moved` block), TFA-3
(consume another stack's outputs with `terraform_remote_state`).

## Scenario

The ledger archive bucket was called `aws_s3_bucket.ledger` in the real state. Someone renamed it
to `aws_s3_bucket.archive` in code, so the next plan would destroy the old bucket and create a new
one. The bucket also keeps history off and encrypts with a key ARN pasted from the platform stack.

## Tasks (edit `main.tf` in the staged copy)

1. Add a `moved` block from `aws_s3_bucket.ledger` to `aws_s3_bucket.archive` (checked statically).
2. (a) Set the versioning status to `Enabled`. (b) Replace the pasted key ARN with the platform
   stack's `kms_key_arn` output, read through `data.terraform_remote_state.platform`. Both are
   graded by the mock apply.
3. (Not graded.) In one sentence each: what must the reader of a `terraform_remote_state` data
   source be allowed to do on the backend, and why does reading it expose more than the one output
   you use?

`reference/` is the worked answer. Do not open it until you are done.

## Versions

Terraform `= 1.10.5` and `hashicorp/aws = 6.71.0`, the versions in the lab image
`hedronite/fullstack-lab-tf:1.10.5-aws` (offline mirror `/opt/tf-mirror`). `starter/` and
`reference/` ship the same `.terraform.lock.hcl` as lab 01. `terraform_remote_state` is built in
and needs no lock entry.

## Stage and grade

```bash
curriculum/week1/tf/stage.sh ~/lab-workspaces/default/week1/tf 20
# edit ~/lab-workspaces/default/week1/tf/20-ledger-archive-moved-and-remote-state/main.tf
curriculum/week1/tf/grade.sh ~/lab-workspaces/default/week1/tf 20
```

```
RESULT 20-ledger-archive-moved-and-remote-state fix FAIL     # starter as staged
RESULT 20-ledger-archive-moved-and-remote-state fix PASS     # after tasks 1 and 2
```

## What the grader can and cannot see

The `moved` block does nothing on an empty mock state, so `check.sh` greps
`main.tf` for it (task 1). The mock apply asserts the versioning status (task 2a) and that the
encryption key equals the overridden `kms_key_arn` output (task 2b). No credentials are mounted.

## CI gate

    ci_gate.py --runner docker --image hedronite/fullstack-lab-tf:1.10.5-aws curriculum/week1/tf/labs/20-ledger-archive-moved-and-remote-state

`sh ./ci-gate.sh [--write-committed-log] [log-file]` is the host/in-image equivalent.
