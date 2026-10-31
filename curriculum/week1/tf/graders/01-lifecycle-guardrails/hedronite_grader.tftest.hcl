# Hedronite lab 01 (lifecycle guardrails) grader.
# Staged as tests/hedronite_grader.tftest.hcl by curriculum/week1/tf/stage.sh.
# Offline by construction: mock_provider means no cloud credentials, no cloud calls, no cost.
# Needs Terraform >= 1.7 for mock_provider; the lab pins 1.10.5 (the lab image).
#
# What a plan can and cannot show:
#   `lifecycle` is a meta-argument. prevent_destroy, ignore_changes and
#   create_before_destroy never appear in the plan or in state, so no assertion here can
#   see them. This grader checks the plan-visible preconditions (a real ledger name, and
#   name_prefix on the security group, without which create_before_destroy collides on the
#   fixed name). The lifecycle blocks themselves are checked by exercise in the README.

mock_provider "aws" {}

run "ledger_has_a_real_name" {
  command = plan

  assert {
    condition     = aws_dynamodb_table.audit_ledger.name != "<hx: name the audit ledger>"
    error_message = "Task 2: the ledger still has the <hx: ...> placeholder name."
  }

  assert {
    condition     = can(regex("^[A-Za-z0-9_.-]{3,255}$", aws_dynamodb_table.audit_ledger.name))
    error_message = "Task 2: a DynamoDB table name is 3-255 characters of letters, digits, '_', '-' and '.'. Plan does not catch this; the API rejects it at apply."
  }
}

run "edge_group_can_be_replaced_before_destroy" {
  command = plan

  assert {
    condition     = aws_security_group.ingress_edge.name_prefix == "hx-ingress-edge-"
    error_message = "Task 5: create_before_destroy needs the old and new group to coexist; a fixed `name` cannot. Use name_prefix = \"hx-ingress-edge-\" instead of name."
  }
}
