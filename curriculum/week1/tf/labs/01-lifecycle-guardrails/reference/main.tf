# Hedronite lab 01 reference: lifecycle guardrails (worked answer).

resource "aws_dynamodb_table" "audit_ledger" {
  name           = "hx-lab01-audit-ledger"
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "event_id"

  attribute {
    name = "event_id"
    type = "S"
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [read_capacity, write_capacity]
  }
}

resource "aws_security_group" "ingress_edge" {
  name_prefix = "hx-ingress-edge-"
  description = "Hedronite lab 01 edge ingress"
  vpc_id      = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }
}

output "ledger_name" {
  value = aws_dynamodb_table.audit_ledger.name
}
