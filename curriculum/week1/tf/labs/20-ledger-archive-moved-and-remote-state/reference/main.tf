# Hedronite lab 20 reference: renamed bucket kept by a moved block, history kept by versioning,
# encryption key read from the platform remote state.

data "terraform_remote_state" "platform" {
  backend = "s3"
  config = {
    bucket = "hx-lab20-platform-state"
    key    = "platform/terraform.tfstate"
    region = "us-east-1"
  }
}

moved {
  from = aws_s3_bucket.ledger
  to   = aws_s3_bucket.archive
}

resource "aws_s3_bucket" "archive" {
  bucket = "hx-lab20-ledger-archive"
}

resource "aws_s3_bucket_versioning" "archive" {
  bucket = aws_s3_bucket.archive.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "archive" {
  bucket = aws_s3_bucket.archive.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = data.terraform_remote_state.platform.outputs.kms_key_arn
    }
  }
}

output "archive_bucket" {
  value = aws_s3_bucket.archive.bucket
}
