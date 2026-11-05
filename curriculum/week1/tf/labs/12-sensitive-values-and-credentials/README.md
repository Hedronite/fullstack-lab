# Lab 12: sensitive values and credentials

Author: Evan Eugene Pincham · Licence: MIT, same as this repository (see `/LICENSE`).
Written for Hedronite from scratch: the scenario, resources, tasks and grader are our own.
It covers exam objectives that public Terraform certification material also covers (marking
variables and outputs sensitive, keeping secrets out of code, keeping provider credentials out
of configuration); no upstream lab text is used.

## Scenario

The on-call engineer found the edge service's database configuration like this. The master
password is an ordinary input variable with a default, so `plan` prints it and a run that
forgets to pass one silently uses the password in the code. An output builds a connection string
from it. Somebody also copied the password into a resource tag "for bootstrap". And the AWS
provider is fed an access key and a secret key through two input variables that have defaults.
`starter/` is valid HCL that gets every one of these wrong.

## Tasks

1. Mark `var.db_password` `sensitive = true` and remove its default, so the value has to come
   from outside the code (`TF_VAR_db_password`, a secrets manager, or a sensitive workspace
   variable in HCP Terraform).
2. Mark `output.db_connection_string` `sensitive = true`. Once the variable is sensitive,
   Terraform refuses to plan an output that uses it unless the output is marked too.
3. Remove the tag that copies the password.
4. Remove the provider's `access_key` and `secret_key` and the two variables that feed them.
   A run takes its credentials from its environment, or, in HCP Terraform, from dynamic provider
   credentials (workspace variables `TFC_AWS_PROVIDER_AUTH` and `TFC_AWS_RUN_ROLE_ARN`).
5. (Not graded.) Marking a value sensitive hides it from CLI output; it does not encrypt it. In
   one sentence: where does the password still sit in plain text after a real apply, and what
   protects it there?

`reference/` is the worked answer. Do not open it until you are done.

## Versions

Terraform `= 1.10.5` and `hashicorp/aws = 6.71.0`, the versions in the lab image
`hedronite/fullstack-lab-tf:1.10.5-aws` (offline mirror `/opt/tf-mirror`). `starter/` and
`reference/` ship the same `.terraform.lock.hcl` as labs 01, 10 and 11, so `init` never
resolves versions over the network.

## Stage and grade

```bash
curriculum/week1/tf/stage.sh ~/lab-workspaces/default/week1/tf 12
# edit ~/lab-workspaces/default/week1/tf/12-sensitive-values-and-credentials/{main,variables,versions}.tf
curriculum/week1/tf/grade.sh ~/lab-workspaces/default/week1/tf 12
```

```
RESULT 12-sensitive-values-and-credentials  fix     FAIL      # starter as staged
RESULT 12-sensitive-values-and-credentials  fix     PASS      # after tasks 1 to 4
```

## What the grader can and cannot see

The grader uses a `mock_provider "aws"`, so no credentials and no cloud calls are involved. A
test can ask whether a value carries the sensitive mark (`issensitive`), so tasks 1 (the mark),
2 and 3 are graded by the test itself, on the plan graph after a mock apply. The mock provider
replaces the `provider` block and the test passes its own value for the password (so a default
would never show), so `check.sh` checks two things on the text of the `.tf` files: that `db_password` has no default
(task 1) and that no `access_key`, `secret_key` or `token` attribute, or credential variable,
remains (task 4). Comments are stripped and whitespace is collapsed, so layout does not matter
but a commented-out line does not count. The HCP Terraform half of task 4 (dynamic provider
credentials) is a workspace setting and is not simulated here.

## CI gate

`check.sh` (POSIX sh, lab root) is the checker, run from `starter/` or `reference/` exactly like
labs 01, 10 and 11 (mktemp work dir, `env -i`, `init -lockfile=readonly`, `terraform test`). Its
embedded grader is a byte copy of `graders/12-sensitive-values-and-credentials/hedronite_grader.tftest.hcl`.

    ci_gate.py --runner docker --image hedronite/fullstack-lab-tf:1.10.5-aws curriculum/week1/tf/labs/12-sensitive-values-and-credentials

`sh ./ci-gate.sh [--write-committed-log] [log-file]` is the host/in-image equivalent (needs the
`graders/` directory two levels up, as in this repository).
