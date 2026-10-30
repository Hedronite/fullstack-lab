# Lab 04 — Remote state backend  ·  grader  (PARTIAL - read the scope note)
# Staged as tests/hedronite_grader.tftest.hcl by curriculum/week1/tf/stage.sh.

mock_provider "aws" {}

run "consumed_remote_values_are_surfaced" {
  command = plan

  assert {
    condition     = try(output.network_outputs != null, false)
    error_message = "output.network_outputs does not resolve. Task 4 asks you to surface the consumed values clearly - a terraform_remote_state data source that nothing reads is not wired in."
  }
}

# ===========================================================================
# SCOPE NOTE - WHAT THIS FILE DOES **NOT** GRADE, AND WHY NOT FAKING IT MATTERS
#
# TASK 1/2 - "the backend block is invalid" / "remove dynamic backend assumptions"
#   A backend block cannot contain variables, locals or any interpolation. It is
#   resolved BEFORE the expression graph exists, so terraform *init* rejects it.
#   ⟹ THAT FAILURE HAPPENS BEFORE `terraform test` EVER RUNS. The grader for this
#     leg is `terraform init` itself:
#         terraform init    # must SUCCEED - on the broken state it will not
#   An assert claiming to check this would be checking nothing, because the test
#   binary never gets to run while the defect is present.
#
# TASK 3 - "use terraform_remote_state correctly"
#   `terraform_remote_state` is a real data source that READS A REAL BACKEND.
#   mock_provider does not cover it (it is a terraform builtin, not the aws
#   provider), so a genuine offline assertion on its CONTENTS is not available
#   on this seat. The assertion above checks only that the output is WIRED,
#   not that the values are correct.
#
# ⟹ THIS GRADER IS PARTIAL AND SAYS SO. A file that asserted all four tasks
#   would pass a learner who satisfied one. Under-claiming is the correct
#   failure direction for an instrument.
# ===========================================================================
