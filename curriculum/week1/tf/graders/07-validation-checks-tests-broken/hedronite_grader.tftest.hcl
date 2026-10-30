# Lab 07 — input validation, preconditions and check blocks  ·  grader (explain lab)
# Offline: mock_provider, so no cloud credentials and no cloud calls. Terraform >= 1.7.
# The lab ships correct; this grader is a regression check for the three guard
# types its README asks for: variable validation (blocking), a resource
# precondition (blocking) and a check block (advisory only).

mock_provider "aws" {}

run "unknown_environment_is_rejected_by_validation" {
  command = plan
  variables {
    environment = "qa"
  }
  expect_failures = [var.environment]
}

run "too_short_name_prefix_is_rejected_by_validation" {
  command = plan
  variables {
    name_prefix = "ab"
  }
  expect_failures = [var.name_prefix]
}

run "prod_on_t3_micro_is_blocked_by_precondition" {
  command = plan
  variables {
    environment   = "prod"
    instance_type = "t3.micro"
  }
  expect_failures = [terraform_data.deployment]
}

run "prod_on_a_larger_type_goes_through" {
  command = apply
  variables {
    environment   = "prod"
    instance_type = "m7g.large"
  }

  assert {
    condition     = output.deployment_summary.environment == "prod" && output.deployment_summary.instance_type == "m7g.large"
    error_message = "A prod deployment on a non-t3.micro type should be accepted and surface its environment and instance type in output.deployment_summary."
  }
}

run "short_but_valid_prefix_only_warns" {
  command = apply
  variables {
    name_prefix = "abc"
  }
  # Advisory: the check block flags it, but nothing is blocked.
  expect_failures = [check.name_prefix_quality]

  assert {
    condition     = output.deployment_summary.name == "abc-dev"
    error_message = "A 3-character prefix passes validation; the deployment name should still be built as <prefix>-<environment>."
  }
}
