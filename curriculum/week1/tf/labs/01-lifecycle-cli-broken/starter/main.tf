# Hedronite lab 01 starter: an S3 log bucket with an expiry rule.
# This file is broken on purpose. See ../README.md for the tasks.

resource "aws_s3_bucket" "logs" {
  # TODO(task 2): pick a real, globally unique, legal S3 bucket name.
  bucket = "REPLACE-ME-WITH-A-UNIQUE-BUCKET-NAME"

  # TODO(task 3): stop Terraform from ever destroying this bucket.
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
