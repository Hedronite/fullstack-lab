# Lab 10: edge provider aliases

Author: Evan Eugene Pincham · Licence: MIT, same as this repository (see `/LICENSE`).
Written for Hedronite from scratch: the scenario, resources, tasks and grader are our own.
It covers exam objectives that public Terraform certification material also covers
(provider aliases, version constraints, provider authentication); no upstream lab text is used.

## Scenario

An edge service publishes release artifacts to an S3 bucket in the primary region and keeps a
replica bucket in a second region, so a rollback never depends on one region. `starter/`
declares an aliased provider for the second region, but the replica bucket never uses it, the
AWS provider is allowed to float to any release from 5.0 on, and the aliased provider
authenticates with static keys written into the configuration.

## Tasks

1. `aws_s3_bucket.releases_dr` must be created through the aliased provider (second region).
   As written it silently lands in the primary region. Opt the resource in to the alias.
2. Bound the `aws` provider to the 6.71 series (`~> 6.71`): 6.71 and later 6.x releases, never
   7.0. The committed `.terraform.lock.hcl` records 6.71.0; say in one sentence what the lock
   file does that the constraint does not.
3. Remove the static `access_key` and `secret_key` from the aliased provider. Authenticate
   through the environment (or shared config) and add an `assume_role` block that names
   `var.dr_role_arn`.
4. (Not graded.) A child module that needs the second region receives the alias through the
   `providers` argument of its `module` block, for example `providers = { aws = aws.dr }`.
   Sketch the block for a module called `replica`.

`reference/` is the worked answer. Do not open it until you are done.

## Versions

Terraform `= 1.10.5` and `hashicorp/aws = 6.71.0`, the versions in the lab image
`hedronite/fullstack-lab-tf:1.10.5-aws` (offline mirror `/opt/tf-mirror`). `starter/` and
`reference/` ship the same `.terraform.lock.hcl` as lab 01, so `init` never resolves versions
over the network.

## Stage and grade

```bash
curriculum/week1/tf/stage.sh ~/lab-workspaces/default/week1/tf 10
# edit ~/lab-workspaces/default/week1/tf/10-edge-provider-aliases/{main,versions}.tf
curriculum/week1/tf/grade.sh ~/lab-workspaces/default/week1/tf 10
```

```
RESULT 10-edge-provider-aliases             fix     FAIL      # starter as staged
RESULT 10-edge-provider-aliases             fix     PASS      # after tasks 1, 2 and 3
```

## What the grader can and cannot see

The grader uses two `mock_provider "aws"` blocks (default and `alias = "dr"`) that give
`aws_s3_bucket` different computed `arn` values, so after a mock `apply` the `arn` of each bucket
shows which provider configuration managed it (task 1). Version constraints and provider
credentials are not visible to a plan, so `check.sh` greps `versions.tf` for tasks 2 and 3 (a
`~> 6.71` or `= 6.71.0` constraint, no `access_key`/`secret_key` lines, an `assume_role` block).
No credentials and no cloud calls are involved.

## CI gate

`check.sh` (POSIX sh, lab root) is the checker, run from `starter/` or `reference/` exactly like
lab 01 (mktemp work dir, `env -i`, `init -lockfile=readonly`, `terraform test`). Its embedded
grader is a byte copy of `graders/10-edge-provider-aliases/hedronite_grader.tftest.hcl`.

    ci_gate.py --runner docker --image hedronite/fullstack-lab-tf:1.10.5-aws curriculum/week1/tf/labs/10-edge-provider-aliases

`sh ./ci-gate.sh [--write-committed-log] [log-file]` is the host/in-image equivalent (needs the
`graders/` directory two levels up, as in this repository).
