# Hedronite lab 13 reference: versioning on, ignore_changes on tags, moved block (worked answer).

moved {
  from = aws_s3_bucket.soak_ledger
  to   = aws_s3_bucket.ledger
}

resource "aws_s3_bucket" "ledger" {
  bucket = "hx-lab13-release-ledger"

  tags = {
    Service = "release-ledger"
  }

  lifecycle {
    # Tags are stamped by an external policy; do not fight it.
    ignore_changes = [tags]
  }
}

resource "aws_s3_bucket_versioning" "ledger" {
  bucket = aws_s3_bucket.ledger.id

  versioning_configuration {
    status = "Enabled"
  }
}

output "ledger_bucket" {
  value = aws_s3_bucket.ledger.bucket
}
