# Lab 01: lifecycle guardrails

Author: Evan Eugene Pincham · Licence: MIT, same as this repository (see `/LICENSE`).
Written for Hedronite. It covers the same exam objective as public Terraform
certification prep material (the `lifecycle` meta-arguments and CLI state inspection);
the scenario, resources, placeholder, tasks and grader are our own.

## Scenario

`starter/` describes two things for an internal audit service:

- `aws_dynamodb_table.audit_ledger`: an append-only ledger. An autoscaler outside
  Terraform tunes its `read_capacity` and `write_capacity`.
- `aws_security_group.ingress_edge`: the edge ingress group. Rule changes force a
  replacement, and traffic must never be left without a group.

The config is valid HCL and plans cleanly, but every guardrail is missing.

## Tasks

1. Stage the lab, run `terraform init`, `terraform validate` and `terraform plan`.
   Note that a clean plan says nothing about how these resources behave on a
   destroy, a replacement or an out-of-band change.
2. The ledger is named `<hx: name the audit ledger>`. Give it a real DynamoDB
   table name (3-255 characters: letters, digits, `_`, `-`, `.`).
3. Losing the ledger loses the audit trail. Make Terraform refuse to destroy it
   (`prevent_destroy`).
4. The autoscaler owns the capacity numbers. Stop Terraform from reverting them on
   every apply (`ignore_changes`), without ignoring anything else.
5. When the edge group is replaced, the new group must exist before the old one is
   removed (`create_before_destroy`). Two groups cannot share one fixed `name` at the
   same moment, so switch to `name_prefix = "hx-ingress-edge-"`.
6. CLI state inspection (not graded; do it against a sandbox apply or the mock run):
   `terraform state list`, then `terraform state show aws_dynamodb_table.audit_ledger`
   and `terraform show -json | jq '.values.root_module.resources[].address'`. Explain
   in two sentences why none of these show your `lifecycle` blocks.

`reference/` is the worked answer. Do not open it until you are done.

## Versions

Terraform `= 1.10.5` and `hashicorp/aws = 6.71.0`, the versions in the lab image
`hedronite/fullstack-lab-tf:1.10.5-aws`. `starter/` and `reference/` each ship a
`.terraform.lock.hcl` with hashes for linux_amd64, linux_arm64, darwin_arm64 and
darwin_amd64, so `init` never resolves versions over the network. Inside the image the
provider comes from the offline mirror `/opt/tf-mirror`.

## Stage and grade

```bash
curriculum/week1/tf/stage.sh ~/lab-workspaces/default/week1/tf 01
# edit ~/lab-workspaces/default/week1/tf/01-lifecycle-guardrails/main.tf
curriculum/week1/tf/grade.sh ~/lab-workspaces/default/week1/tf 01
```

The grader uses `mock_provider "aws"`: no credentials, no cloud calls.

```
RESULT 01-lifecycle-guardrails             fix     FAIL      # starter as staged
RESULT 01-lifecycle-guardrails             fix     PASS      # after tasks 2 and 5
```

## What the grader can and cannot see

`lifecycle` is a meta-argument: it is not in the plan or in state, so `terraform test`
cannot assert on `prevent_destroy`, `ignore_changes` or `create_before_destroy`. The
grader checks the plan-visible preconditions (a legal ledger name; `name_prefix` on the
edge group). Check the guardrails by exercise after a sandbox apply:

```bash
terraform plan -destroy        # must error: "Instance cannot be destroyed" (task 3)
# change read_capacity in the console, then:
terraform plan                 # must show no change to the table (task 4)
# change the group's description, then:
terraform plan                 # must say "create replacement and then destroy" (task 5)
```

## CI gate

`check.sh` (POSIX sh, lab root) is the checker. Run from `starter/` or `reference/`,
it copies the `.tf` files and lock file into a mktemp dir (removed on exit), stages the
grader there, and runs `terraform init` + `terraform test` under `env -i` (PATH, LANG, a
throwaway HOME, TF_IN_AUTOMATION, TF_CLI_CONFIG_FILE only), then prints
`RESULT 01-lifecycle-guardrails fix PASS|FAIL`. It never writes into the tree. Its
embedded grader is a byte copy of `graders/01-lifecycle-guardrails/hedronite_grader.tftest.hcl`.

The containerised gate is the curriculum `ci_gate.py`, pointed straight at this dir:

    ci_gate.py --runner docker --image hedronite/fullstack-lab-tf:1.10.5-aws curriculum/week1/tf/labs/01-lifecycle-guardrails

`sh ./ci-gate.sh [--write-committed-log] [log-file]` is the host/in-image equivalent (no
bash needed): reference PASS, starter FAIL on a grader assertion, no grader drift. Its log
goes to the given file, else `$CI_GATE_LOG`, else stdout only; only
`--write-committed-log` rewrites the committed `ci-gate.log` (which is from an earlier
run, before the rename). If you set `CI_GATE_TF_CLI_CONFIG`, point it at a config that
holds only a `provider_installation` mirror block: a CLI config can also carry registry
credentials, and those must not reach the gate.
