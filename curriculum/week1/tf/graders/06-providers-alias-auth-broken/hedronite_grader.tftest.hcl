# Lab 06 — Provider aliasing across regions  ·  grader
# Offline: mock_provider ⟹ no cloud credentials, no cloud calls, no cost. Terraform >= 1.7.
# Coverage gap: README tasks 2-3 (pass both providers into a child module that
# declares configuration_aliases) are NOT checked; a test file cannot address a
# module whose name the student chooses. Review those by hand.

mock_provider "aws" {}
mock_provider "aws" { alias = "secondary" }

run "both_regions_are_surfaced" {
  command = plan

  assert {
    condition     = try(output.primary_region != "" && output.primary_region != null, false)
    error_message = "output.primary_region does not resolve. Task 4 asks you to show both regions clearly in outputs."
  }

  assert {
    condition     = try(output.secondary_region != "" && output.secondary_region != null, false)
    error_message = "output.secondary_region does not resolve. The aliased provider is not wired through to an output."
  }
}

run "the_two_providers_are_actually_distinct" {
  command = plan

  # The whole point of an alias is a SECOND configuration. If both outputs report
  # the same region, the alias exists in name only and nothing was really aliased.
  assert {
    condition     = try(output.primary_region != output.secondary_region, false)
    error_message = "primary_region and secondary_region are identical. An alias that resolves to the same region as the default provider is not a second configuration - check that the aliased provider block sets its own region and that the resource/module actually references provider = aws.secondary."
  }
}
