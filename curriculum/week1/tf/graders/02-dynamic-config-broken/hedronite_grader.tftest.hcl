# Lab 02 — Dynamic Config: count -> for_each  ·  grader
# Staged as tests/hedronite_grader.tftest.hcl by curriculum/week1/tf/stage.sh.
# Run with: terraform init && terraform test
#
# Offline by construction: mock_provider means NO cloud credentials, NO cloud calls, NO cost.
# Requires Terraform >= 1.7 for mock_provider.

mock_provider "aws" {}

run "resources_are_no_longer_index_addressed" {
  command = plan

  # The whole point of the refactor. With for_each the address is a STRING KEY,
  # so [0] no longer resolves - try() collapses that failure to false.
  assert {
    condition     = !try(aws_s3_bucket.this[0].bucket != "", false)
    error_message = "aws_s3_bucket.this is still index-addressed, so count is still in use. Removing an early list element renumbers every resource after it - that is the defect this lab exists to remove."
  }

  assert {
    condition     = try(aws_s3_bucket.this["logs"].bucket != "", false)
    error_message = "Expected aws_s3_bucket.this to be keyed by bucket name (for_each over a map), so that 'logs' is a stable address independent of ordering."
  }
}

run "input_is_map_shaped_with_stable_keys" {
  command = plan

  assert {
    condition     = try(length(keys(var.buckets)) == 3, false)
    error_message = "var.buckets should be a map(object(...)) with 3 entries. keys() fails on a list - if this errors, the input is still list-shaped."
  }

  assert {
    condition     = try(toset(keys(var.buckets)) == toset(["logs", "assets", "archive"]), false)
    error_message = "Map keys should be the bucket names logs, assets and archive - the keys are what make the addresses stable, so they must carry the identity."
  }
}

run "outputs_are_map_shaped" {
  command = plan

  assert {
    condition     = try(output.bucket_names["logs"] != "", false)
    error_message = "output.bucket_names should be a MAP keyed by bucket name, not a list from a [*] splat. A consumer indexing by name must not break when an element is removed."
  }

  assert {
    condition     = try(toset(keys(output.bucket_names)) == toset(["logs", "assets", "archive"]), false)
    error_message = "output.bucket_names should expose exactly the three configured keys."
  }
}

# NOTE ON try(): every condition is wrapped because an assertion that ERRORS
# aborts the test run, whereas one that returns false FAILS it and prints the
# error_message. On the broken starting state these are all type errors -
# without try() the learner would see a Terraform stack trace instead of the
# message written to teach them.
