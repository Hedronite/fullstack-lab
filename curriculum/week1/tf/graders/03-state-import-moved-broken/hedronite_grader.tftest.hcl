# Lab 03 — Import, child module, moved block  ·  grader
# Staged as tests/hedronite_grader.tftest.hcl by curriculum/week1/tf/stage.sh.
# Offline: mock_provider ⟹ no cloud credentials, no cloud calls, no cost. Terraform >= 1.7.

mock_provider "aws" {}

run "resource_moved_out_of_the_root_module" {
  command = plan

  # After refactoring into a child module the ROOT address must no longer resolve.
  # try() collapses the expected type error to false so the learner sees the message,
  # not a stack trace.
  assert {
    condition     = !try(aws_s3_bucket.logs.bucket != "", false)
    error_message = "aws_s3_bucket.logs still resolves at the ROOT. Task 2 asks you to refactor it into a child module - the resource should now live at module.<name>.aws_s3_bucket.logs."
  }
}

run "consumers_did_not_break" {
  command = plan

  # THE ACTUAL SUCCESS CRITERION. A moved block exists so that a refactor is
  # invisible to anyone consuming the output. If the output still resolves and
  # still carries the configured name, the move preserved the contract.
  assert {
    condition     = try(output.bucket_name != "" && output.bucket_name != null, false)
    error_message = "output.bucket_name no longer resolves. A refactor that breaks a published output has defeated the purpose of the moved block - consumers must not have to change."
  }

  assert {
    condition     = try(output.bucket_name == var.bucket_name, false)
    error_message = "output.bucket_name should still surface var.bucket_name after the move. If it drifted, the child module is not being fed the same input."
  }
}

# ---------------------------------------------------------------------------
# DELIBERATELY NOT ASSERTED — and this is a design decision, not an omission:
#
#   The MODULE NAME is the learner's free choice. A grader that demanded
#   module.storage would be grading conformity to my taste, not correctness.
#   The two properties that actually matter are asserted above:
#     (1) the resource left the root, and
#     (2) the published output still works.
#
#   `moved` is also a top-level block, not an attribute, so - like `lifecycle`
#   in Lab 01 - terraform test cannot see it directly. What it CAN see is the
#   consequence: a plan with a moved block shows a MOVE, whereas a plan without
#   one shows a DESTROY + CREATE. Verify by exercise:
#       terraform plan    # must NOT propose destroying and recreating the bucket
# ---------------------------------------------------------------------------
