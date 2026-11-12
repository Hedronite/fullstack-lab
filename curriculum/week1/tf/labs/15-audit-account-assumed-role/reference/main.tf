# Hedronite lab 15 reference: the worked answer. Do not open it until you are done.

resource "aws_s3_bucket" "edge_logs" {
  bucket = "hx-lab15-edge-logs"
}

# provider = aws.audit sends this bucket to the audit account.
resource "aws_s3_bucket" "audit_logs" {
  provider = aws.audit
  bucket   = "hx-lab15-audit-logs"
}

output "sink_url" {
  value     = "https://sink.mock.internal/v1/logs?key=${var.sink_api_key}&bucket=${aws_s3_bucket.audit_logs.id}"
  sensitive = true
}
