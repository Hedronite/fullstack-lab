# Lab 19: queue retry and dead letters

Author: Evan Eugene Pincham · Licence: MIT, same as this repository (see `/LICENSE`).
Written for Hedronite from scratch: the scenario, resources, tasks and grader are our own.
It covers exam objectives that public Terraform certification material also covers
(import blocks, version constraints, provider requirements); no upstream lab text is used.

## Scenario

A deploy tool hands its work to an SQS queue and a worker reads it. When a message cannot be
processed, it should land in a dead-letter queue instead of blocking the worker. `starter/` keeps
messages for one minute, lets a poison message be received fifty times before it moves to the
dead-letter queue, leaves that dead-letter queue (already created by hand in the account)
outside Terraform's control, and accepts every Terraform release from 0.13 on and every AWS
provider from 5.0 on.

## Tasks

1. (a) Keep messages at least 4 days: `message_retention_seconds` of 345600 or more.
   (b) Move a poison message to the dead-letter queue after at most 5 receives (`maxReceiveCount`).
2. The dead-letter queue `hx-lab19-events-dlq` already exists. Add an `import` block that adopts it into
   `aws_sqs_queue.dlq` (the id of an SQS queue is its queue URL).
3. (a) Bound `required_version` to the 1.10 series with `~> 1.10`. (b) Bound the AWS provider with `~> 6.71`.
4. (Not graded.) In one sentence each: what does `terraform plan` show for an `import` block
   before it is applied, and what does `.terraform.lock.hcl` pin that the version constraints do not?

`reference/` is the worked answer. Do not open it until you are done.

## Versions

Terraform `= 1.10.5` and `hashicorp/aws = 6.71.0`, the versions in the lab image
`hedronite/fullstack-lab-tf:1.10.5-aws` (offline mirror `/opt/tf-mirror`). `starter/` and
`reference/` ship the same `.terraform.lock.hcl` as lab 01.

## Stage and grade

```bash
curriculum/week1/tf/stage.sh ~/lab-workspaces/default/week1/tf 19
# edit ~/lab-workspaces/default/week1/tf/19-queue-retry-and-dead-letters/{main,versions}.tf
curriculum/week1/tf/grade.sh ~/lab-workspaces/default/week1/tf 19
```

```
RESULT 19-queue-retry-and-dead-letters fix FAIL     # starter as staged
RESULT 19-queue-retry-and-dead-letters fix PASS     # after tasks 1, 2 and 3
```

## What the grader can and cannot see

The grader uses `mock_provider "aws"`: it applies the configuration against the mock and asserts
the retention period (task 1a) and the redrive limit decoded from `redrive_policy` (task 1b).
The `import` block and the version bounds are not observable in a mock apply, so `check.sh`
greps `main.tf` for the `import` block (task 2) and `versions.tf` for both bounds (task 3).
No credentials and no cloud calls are involved.

## CI gate

    ci_gate.py --runner docker --image hedronite/fullstack-lab-tf:1.10.5-aws curriculum/week1/tf/labs/19-queue-retry-and-dead-letters

`sh ./ci-gate.sh [--write-committed-log] [log-file]` is the host/in-image equivalent (needs the
`graders/` directory two levels up, as in this repository).
