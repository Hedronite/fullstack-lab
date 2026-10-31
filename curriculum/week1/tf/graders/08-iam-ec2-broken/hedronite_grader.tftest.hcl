# Lab 08 — IAM role, policy and instance profile wired to EC2  ·  grader
# Offline: mock_provider means no cloud credentials, no cloud calls, no cost. Terraform >= 1.7.
# Every run applies against the MOCK provider only: nothing is created in AWS.
# Note: the upstream lab as shipped already satisfies these checks (see curriculum/README.md).

mock_provider "aws" {
  # Policy-document JSON is mocked to a valid object so the role/policy plan
  # does not fail on a random mock string; statements are still read from config.
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
  mock_data "aws_ami" {
    defaults = { id = "ami-0123456789abcdef0" }
  }
}

run "iam_chain_is_wired_to_ec2" {
  command = apply

  # Task: fix the IAM trust policy (EC2 must be able to assume the role).
  assert {
    condition = anytrue([
      for s in data.aws_iam_policy_document.trust.statement :
      s.effect == "Allow" && contains(s.actions, "sts:AssumeRole") &&
      anytrue([for p in s.principals : p.type == "Service" && contains(p.identifiers, "ec2.amazonaws.com")])
    ])
    error_message = "Trust policy must Allow sts:AssumeRole for Service principal ec2.amazonaws.com."
  }

  # Task: create a working permissions policy (at least one Allow statement with actions).
  assert {
    condition = anytrue([
      for s in data.aws_iam_policy_document.permissions.statement :
      s.effect == "Allow" && length(s.actions) > 0 && length(s.resources) > 0
    ])
    error_message = "Permissions policy needs an Allow statement with actions and resources."
  }

  # Task: create the instance profile, bound to the role.
  assert {
    condition     = aws_iam_instance_profile.app.role == aws_iam_role.app.name
    error_message = "Instance profile must reference aws_iam_role.app."
  }

  # Task: attach the instance profile to EC2.
  assert {
    condition     = aws_instance.app.iam_instance_profile == aws_iam_instance_profile.app.name
    error_message = "aws_instance.app must use aws_iam_instance_profile.app."
  }
}

# The role id is computed, so plan cannot see which role the policy lands on.
# This run applies against the MOCK provider only (no AWS calls, nothing created).
run "policy_is_attached_to_the_role" {
  command = apply

  override_resource {
    target = aws_iam_role.app
    values = { id = "tfpro-iam-role" }
  }

  # Task: attach the policy to the role.
  assert {
    condition     = aws_iam_role_policy.app.role == aws_iam_role.app.id
    error_message = "aws_iam_role_policy.app must be attached to aws_iam_role.app."
  }
}
