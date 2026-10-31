# Hedronite lab 01 starter: lifecycle guardrails.
# An audit ledger (DynamoDB) whose read/write capacity is tuned by an autoscaler outside
# Terraform, and an ingress security group that is replaced whenever its rules change.
# Valid HCL, wrong behaviour on purpose. See ../README.md for the tasks.

resource "aws_dynamodb_table" "audit_ledger" {
  # TODO(task 2): give the ledger a real name.
  name           = "<hx: name the audit ledger>"
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "event_id"

  attribute {
    name = "event_id"
    type = "S"
  }

  # TODO(task 3): this table must survive a careless `terraform destroy`.
  # TODO(task 4): the autoscaler owns read_capacity and write_capacity; stop Terraform
  #               from reverting them on every apply.
}

resource "aws_security_group" "ingress_edge" {
  # TODO(task 5): a replacement must exist before the old group is removed, and a fixed
  #               name cannot be held by two groups at once.
  name        = "hx-ingress-edge"
  description = "Hedronite lab 01 edge ingress"
  vpc_id      = var.vpc_id
}

output "ledger_name" {
  value = aws_dynamodb_table.audit_ledger.name
}
