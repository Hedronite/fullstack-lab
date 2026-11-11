# Lab 14: ledger shards and state

Author: Evan Eugene Pincham · Licence: MIT, same as this repository (see `/LICENSE`).
Written for Hedronite from scratch: the scenario, resources, tasks and grader are our own.
It covers exam objectives that public Terraform certification material also covers (importing
resources, removing resources from state, remote state configuration and locking, reconciling
drift); no upstream lab text is used.

## Scenario

The release ledger outgrew one bucket. Over a quarter, three shard buckets (`hx-lab14-a`,
`hx-lab14-b`, `hx-lab14-c`) were created by hand in the console. The configuration lists only
two of them, none of them is in state, a scratch bucket that another team now owns is still
managed here, and the S3 backend block has the production state bucket and key typed in with no
locking. `starter/` is valid HCL that gets every one of these wrong.

## Tasks

1. The real account holds three shards (a, b and c) but `var.shards` stops at b. Add the missing
   shard.
2. None of the shard buckets is in state, so the next plan wants to create them. Adopt all of them
   with **one** `import` block that uses `for_each = var.shards`, with
   `to = aws_s3_bucket.shard[each.key]` and `id = "hx-lab14-${each.key}"`.
3. `aws_s3_bucket.scratch_ledger` now belongs to another team. Stop managing it without destroying
   the real bucket, as a reviewed change to the configuration: delete the resource block and add a
   `removed` block (`from = aws_s3_bucket.scratch_ledger`, `lifecycle { destroy = false }`).
4. Make the `s3` backend a partial configuration: take `bucket` and `key` out of the `backend`
   block, set `use_lockfile = true` (native S3 locking, no DynamoDB), and create
   `prod.s3.tfbackend` beside the `.tf` files with the `bucket` and `key` lines, so a run starts
   with `terraform init -backend-config=prod.s3.tfbackend`.
5. (Not graded.) Someone changed a bucket tag in the console during an incident. In one sentence
   each: which command shows that drift as a proposed state-only update without touching the
   infrastructure, what does approving it do, and which command releases a state lock left
   behind by a killed CI run?

`reference/` is the worked answer. Do not open it until you are done.

## Versions

Terraform `~> 1.10` (the lab image runs 1.10.5) and `hashicorp/aws = 6.71.0`, the versions in the
lab image `hedronite/fullstack-lab-tf:1.10.5-aws` (offline mirror `/opt/tf-mirror`). `starter/`
and `reference/` ship the same `.terraform.lock.hcl` as lab 13.

## Stage and grade

```bash
curriculum/week1/tf/stage.sh ~/lab-workspaces/default/week1/tf 14
# edit ~/lab-workspaces/default/week1/tf/14-ledger-shards-and-state/{main,variables,versions}.tf
# and add prod.s3.tfbackend
curriculum/week1/tf/grade.sh ~/lab-workspaces/default/week1/tf 14
```

```
RESULT 14-ledger-shards-and-state fix FAIL     # starter as staged
RESULT 14-ledger-shards-and-state fix PASS     # after tasks 1, 2, 3 and 4
```

## What the grader can and cannot see

The grader uses `mock_provider "aws"`: it applies the configuration against the mock and asserts
that all three shard buckets are managed (task 1). A mock provider cannot import, a test run has
no prior state and backends are skipped, so `check.sh` checks the `import` block (task 2), the
`removed` block (task 3) and the backend settings plus `prod.s3.tfbackend` (task 4) statically on
the text. No credentials and no cloud calls are involved.

## CI gate

    ci_gate.py --runner docker --image hedronite/fullstack-lab-tf:1.10.5-aws curriculum/week1/tf/labs/14-ledger-shards-and-state

`sh ./ci-gate.sh [--write-committed-log] [log-file]` is the host/in-image equivalent (needs the
`graders/` directory two levels up, as in this repository).
