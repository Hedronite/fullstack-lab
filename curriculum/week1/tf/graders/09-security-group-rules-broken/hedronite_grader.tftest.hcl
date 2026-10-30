# Lab 09 — Security group with separate rule resources  ·  grader
# Offline: mock_provider ⟹ no cloud credentials, no cloud calls, no cost. Terraform >= 1.7.
# Runs use `command = apply` against the MOCK provider (nothing is created in AWS):
# ingress/egress are computed on aws_security_group, so at plan they are unknown
# and the inline-vs-separate check cannot be evaluated. The mock defaults below
# only fill attributes the configuration leaves unset; inline blocks written in
# config still show up and fail the check.

mock_provider "aws" {
  mock_resource "aws_security_group" {
    defaults = {
      id      = "sg-0123456789abcdef0"
      ingress = []
      egress  = []
    }
  }
}

run "rules_are_separate_resources_not_inline_blocks" {
  command = apply

  # Mixing inline ingress/egress blocks with separate rule resources makes
  # each apply revoke the other's rules, so the inline collections must be EMPTY.
  assert {
    condition     = length(aws_security_group.web.ingress) == 0
    error_message = "aws_security_group.web still declares INLINE ingress blocks. Task 2 asks for separate aws_vpc_security_group_ingress_rule resources. Mixing inline blocks with separate rule resources makes each apply revoke the other's rules."
  }

  assert {
    condition     = length(aws_security_group.web.egress) == 0
    error_message = "aws_security_group.web still declares INLINE egress blocks. Task 3 asks for a separate aws_vpc_security_group_egress_rule resource."
  }

  assert {
    condition     = try(aws_vpc_security_group_egress_rule.web.security_group_id == aws_security_group.web.id, false)
    error_message = "aws_vpc_security_group_egress_rule.web is missing or not attached to aws_security_group.web."
  }
}

run "ingress_rules_are_keyed_by_every_allowed_port" {
  command = apply

  assert {
    condition     = try(length(aws_vpc_security_group_ingress_rule.web) == length(var.allowed_ports), false)
    error_message = "The number of ingress rule resources does not match the number of entries in var.allowed_ports. for_each should produce exactly one rule per allowed port."
  }

  assert {
    condition     = try(alltrue([for p in var.allowed_ports : contains(keys(aws_vpc_security_group_ingress_rule.web), tostring(p))]), false)
    error_message = "Every port in var.allowed_ports must appear as a for_each KEY, so each rule has a stable address. If ports are index-keyed, removing one renumbers the rest and Terraform destroys and recreates unrelated rules."
  }

  assert {
    condition     = try(alltrue([for r in values(aws_vpc_security_group_ingress_rule.web) : r.security_group_id == aws_security_group.web.id]), false)
    error_message = "Every ingress rule must reference aws_security_group.web.id."
  }
}

run "security_group_id_is_published" {
  command = apply

  assert {
    condition     = try(output.security_group_id == aws_security_group.web.id, false)
    error_message = "output.security_group_id must publish aws_security_group.web.id. Task 5 asks you to output the security group id so downstream stacks can consume it."
  }
}
