# Hedronite lab 15 starter: the edge service and its audit account as the on-call engineer
# found them. Valid HCL, wrong behaviour on purpose. See ../README.md for the tasks.

resource "aws_s3_bucket" "edge_logs" {
  bucket = "hx-lab15-edge-logs"
}

# TODO(task 1): this bucket must live in the AUDIT account, not the edge account. A resource
#               goes to a non-default provider configuration only when it says so
#               (provider = aws.audit). Without it the bucket lands in the edge account.
resource "aws_s3_bucket" "audit_logs" {
  bucket = "hx-lab15-audit-logs"
}

# TODO(task 2): this value contains the sink API key. Once the variable is sensitive, Terraform
#               refuses to plan a root output that uses it unless the output says so too.
output "sink_url" {
  value = "https://sink.mock.internal/v1/logs?key=${var.sink_api_key}&bucket=${aws_s3_bucket.audit_logs.id}"
}
