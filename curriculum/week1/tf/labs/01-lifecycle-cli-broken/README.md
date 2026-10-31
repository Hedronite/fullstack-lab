# Lab 01: lifecycle and CLI (broken)

Author: Evan Eugene Pincham · Licence: MIT, same as this repository (see `/LICENSE`).
Written for Hedronite from scratch; it is not derived from any third-party lab.

## Task

`starter/` describes one S3 bucket for logs plus a lifecycle rule that deletes
objects under `logs/` after `var.expire_after_days` days. It is broken.
(Task numbers match the grader messages.)

1. Run `terraform init` and `terraform validate` in the staged dir and read
   `main.tf`: it is valid HCL, so the CLI alone will not tell you what is wrong.
2. The bucket name is a placeholder, and the placeholder is not even a legal S3
   name (uppercase letters). Replace it with a globally unique name that is
   3–63 characters, lowercase letters, digits, dots and hyphens, starts and ends
   with a letter or digit, and is not shaped like an IP address. A plan will not
   catch an illegal name; the S3 API rejects it at apply time.
3. The bucket holds logs you must not lose. Add `lifecycle { prevent_destroy = true }`
   to `aws_s3_bucket.logs`.

`reference/` is the worked answer. Do not open it until you are done.

## Stage and grade

```bash
curriculum/week1/tf/stage.sh ~/lab-workspaces/default/week1/tf 01
# edit ~/lab-workspaces/default/week1/tf/01-lifecycle-cli-broken/main.tf
curriculum/week1/tf/grade.sh ~/lab-workspaces/default/week1/tf 01
```

Terraform >= 1.7 (the grader uses `mock_provider "aws"`: no credentials, no cloud calls).

Expected `RESULT` lines:

```
RESULT 01-lifecycle-cli-broken             fix     FAIL      # starter as staged
RESULT 01-lifecycle-cli-broken             fix     PASS      # after tasks 2 and 3
```

## Manual check (task 3)

`lifecycle` is a meta-argument; it is not in the plan, so `terraform test` cannot
see it. Check the behaviour instead, in the staged lab dir:

```bash
terraform plan -destroy   # must error: "Instance cannot be destroyed"
```

Against real AWS this needs credentials and state; with nothing applied yet,
`plan -destroy` has nothing to destroy, so do this check after an apply in a
sandbox account, or review the block by eye.

## CI gate

`check.sh` (POSIX sh, at the lab root) is the checker: run inside a copy of
`starter/` or `reference/`, it stages the grader into `tests/`, runs
`terraform init` + `terraform test`, and prints
`RESULT 01-lifecycle-cli-broken fix PASS|FAIL`. Its embedded grader is a byte copy
of `graders/01-lifecycle-cli-broken/hedronite_grader.tftest.hcl`.

The containerised gate is the curriculum `ci_gate.py`, pointed straight at this dir:

    ci_gate.py --runner docker --image hedronite/fullstack-lab-tf:1.10.5-aws curriculum/week1/tf/labs/01-lifecycle-cli-broken

`sh ./ci-gate.sh [log-file]` is the host/in-image equivalent (no bash needed): it
copies `reference/` and `starter/` into clean temp dirs with `check.sh` and checks
reference PASS, starter FAIL on a grader assertion, and no drift between the two
grader copies. In the lab image, set `CI_GATE_TF_CLI_CONFIG=/root/.terraformrc`
so terraform finds the offline provider mirror. Output goes to `ci-gate.log`
(or the given file); the committed log is from an earlier run.
