# Hedronite lab 01 reference: an S3 log bucket with an expiry rule.

resource "aws_s3_bucket" "logs" {
  bucket = "hedronite-lab01-logs-7f3c2a"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "expire-logs"
    status = "Enabled"

    filter {
      prefix = "logs/"
    }

    expiration {
      days = var.expire_after_days
    }
  }
}

output "bucket_name" {
  value = aws_s3_bucket.logs.bucket
}
