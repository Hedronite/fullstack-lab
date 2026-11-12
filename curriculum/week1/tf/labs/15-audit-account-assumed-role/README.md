# Lab 15: audit account and assumed role

Author: Evan Eugene Pincham · Licence: MIT, same as this repository (see `/LICENSE`).
Written for Hedronite from scratch: the scenario, resources, tasks and grader are our own.
It covers exam objectives that public Terraform certification material also covers (sending a
resource to a second provider configuration, assuming a role instead of storing keys, marking
variables and outputs sensitive); no upstream lab text is used.

## Scenario

The edge service writes its logs to a bucket in its own AWS account and must also keep a copy in a
separate audit account. The on-call engineer found it like this. The audit bucket carries no
`provider` argument, so it is created in the edge account. The audit provider is fed a long-lived
access key and secret key through two input variables that have defaults. And the audit sink's API
key is a plain input variable with a default, used in an output URL that is not marked sensitive.
`starter/` is valid HCL that gets all of these wrong.

## Tasks

1. Send `aws_s3_bucket.audit_logs` to the audit account with `provider = aws.audit`.
2. Mark `var.sink_api_key` `sensitive = true` and remove its default, then mark `output.sink_url`
   `sensitive = true` (Terraform refuses to plan a root output built from a sensitive value unless
   the output says so too).
3. Replace the audit provider's `access_key` and `secret_key` with an `assume_role` block
   (`role_arn = var.audit_role_arn`) and delete the two variables that fed the keys. The run's own
   credentials assume the role; no key for the audit account exists in configuration.
4. (Not graded.) In one sentence each: what must the audit account's role trust policy allow for
   this to work, and, after a real apply, where does the sink API key still sit in plain text even
   though it is marked sensitive? Which Terraform 1.10 feature keeps a value out of state, and why
   can it not be used for this particular key?

`reference/` is the worked answer. Do not open it until you are done.

## Versions

Terraform `= 1.10.5` and `hashicorp/aws = 6.71.0`, the versions in the lab image
`hedronite/fullstack-lab-tf:1.10.5-aws` (offline mirror `/opt/tf-mirror`). `starter/` and
`reference/` ship the same `.terraform.lock.hcl` as labs 01 and 10 to 14, so `init` never resolves
versions over the network.

## Stage and grade

```bash
curriculum/week1/tf/stage.sh ~/lab-workspaces/default/week1/tf 15
# edit ~/lab-workspaces/default/week1/tf/15-audit-account-assumed-role/{main,variables,versions}.tf
curriculum/week1/tf/grade.sh ~/lab-workspaces/default/week1/tf 15
```

```
RESULT 15-audit-account-assumed-role  fix     FAIL      # starter as staged
RESULT 15-audit-account-assumed-role  fix     PASS      # after tasks 1 to 3
```

## What the grader can and cannot see

The grader uses two `mock_provider "aws"` blocks, the second with `alias = "audit"`. Each gives
buckets a different ARN, so a bucket created through the wrong provider configuration shows up in
its ARN (task 1). A test can ask whether a value carries the sensitive mark (`issensitive`), so
task 2's marks are graded by the test itself. The mock providers replace the `provider` blocks, so
`check.sh` checks on the text of the `.tf` files that `sink_api_key` has no default (task 2) and
that the audit provider has no `access_key`, `secret_key` or `token` and does have an
`assume_role` block with a `role_arn` (task 3). Comments are stripped and whitespace is collapsed,
so layout does not matter but a commented-out line does not count. Nothing here calls STS: the
role trust policy is not simulated.

## CI gate

`check.sh` (POSIX sh, lab root) is the checker, run from `starter/` or `reference/` exactly like
labs 12 to 14. Its embedded grader is a byte copy of
`graders/15-audit-account-assumed-role/hedronite_grader.tftest.hcl`.

    ci_gate.py --runner docker --image hedronite/fullstack-lab-tf:1.10.5-aws curriculum/week1/tf/labs/15-audit-account-assumed-role

`sh ./ci-gate.sh [--write-committed-log] [log-file]` is the host/in-image equivalent (needs the
`graders/` directory two levels up, as in this repository).
