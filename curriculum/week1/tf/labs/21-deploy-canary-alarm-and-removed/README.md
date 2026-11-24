# Lab 21: deploy canary alarm and removed block

Author: Evan Eugene Pincham · Licence: MIT, same as this repository (see `/LICENSE`).
Written for Hedronite from scratch: the scenario, resources, tasks and grader are our own.
It covers exam objectives that public Terraform certification material also covers
(resource lifecycle, `removed` blocks); no upstream lab text is used.

## Scenario

A release pipeline watches a canary Lambda through a CloudWatch alarm and notifies an SNS topic.
`starter/` trips on a single bad minute, calls a silent canary healthy, notifies nobody, would
destroy the topic before building its replacement, and still manages a legacy alarm that another
team is taking over.

## Tasks

1. On `aws_cloudwatch_metric_alarm.canary_errors`: (a) `evaluation_periods` of 2 or more;
   (b) `treat_missing_data = "breaching"`; (c) `alarm_actions` containing the topic ARN.
2. Make `aws_sns_topic.alerts` build its replacement first (`lifecycle { create_before_destroy = true }`).
3. Stop managing `aws_cloudwatch_metric_alarm.legacy_latency` without destroying it: remove the
   resource and add a `removed` block with `lifecycle { destroy = false }`.
4. (Not graded.) In one sentence each: what does `terraform plan` show for a `removed` block with
   `destroy = false`, and how does that differ from `terraform state rm`?

`reference/` is the worked answer. Do not open it until you are done.

## Versions

Terraform `= 1.10.5` and `hashicorp/aws = 6.71.0`, the versions in the lab image
`hedronite/fullstack-lab-tf:1.10.5-aws` (offline mirror `/opt/tf-mirror`). `starter/` and
`reference/` ship the same `.terraform.lock.hcl` as lab 01.

## Stage and grade

```bash
curriculum/week1/tf/stage.sh ~/lab-workspaces/default/week1/tf 21
# edit ~/lab-workspaces/default/week1/tf/21-deploy-canary-alarm-and-removed/main.tf
curriculum/week1/tf/grade.sh ~/lab-workspaces/default/week1/tf 21
```

```
RESULT 21-deploy-canary-alarm-and-removed fix FAIL     # starter as staged
RESULT 21-deploy-canary-alarm-and-removed fix PASS     # after tasks 1, 2 and 3
```

## What the grader can and cannot see

The grader uses `mock_provider "aws"`: it applies the configuration against the mock and asserts
tasks 1a to 1c. `create_before_destroy` and the `removed` block are not observable in a mock apply,
so `check.sh` greps `main.tf` for them (tasks 2 and 3). No credentials and no cloud calls are involved.

## CI gate

    ci_gate.py --runner docker --image hedronite/fullstack-lab-tf:1.10.5-aws curriculum/week1/tf/labs/21-deploy-canary-alarm-and-removed

`sh ./ci-gate.sh [--write-committed-log] [log-file]` is the host/in-image equivalent (needs the
`graders/` directory two levels up, as in this repository).
