# Lab 05 — Workspaces and cross-stack consumption  ·  grader  (PARTIAL - see scope note)
# Staged as tests/hedronite_grader.tftest.hcl by curriculum/week1/tf/stage.sh.

mock_provider "aws" {}

run "environment_tracks_the_workspace" {
  command = plan

  assert {
    condition     = try(output.selected_environment == terraform.workspace, false)
    error_message = "output.selected_environment does not equal terraform.workspace. Task 1 asks that outputs reflect the selected workspace rather than a hardcoded environment name."
  }
}

run "instance_type_is_surfaced" {
  command = plan

  assert {
    condition     = try(output.instance_type == var.instance_type, false)
    error_message = "output.instance_type should surface the resolved var.instance_type so the prod guard in Task 3 is observable from outside the module."
  }
}

# ===========================================================================
# SCOPE NOTE - TWO TASKS DELIBERATELY NOT ASSERTED HERE
#
# TASK 2 - "consume upstream values via terraform_remote_state"
#   Same limit as Lab 04: terraform_remote_state is a TERRAFORM BUILTIN that
#   reads a real backend. mock_provider covers the aws provider, not this.
#   An offline assertion on output.network_outputs' CONTENTS is unavailable.
#
# TASK 3 - "block t3.micro in prod"
#   This is a guard that must FAIL on bad input, so asserting it needs a run
#   block with `expect_failures` against the prod workspace - and a test run
#   cannot select a workspace from inside the file. Exercise it directly:
#       terraform workspace select prod
#       terraform plan -var instance_type=t3.micro   # must FAIL
#   A grader that ran only the happy path would report PASS on a guard that
#   never fires - which is the failure mode the guard exists to prevent.
# ===========================================================================
