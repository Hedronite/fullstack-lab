# Hedronite lab 20 starter: a ledger archive bucket that was renamed in code. Valid HCL, wrong
# behaviour on purpose. See ../README.md for the tasks.

# The platform stack publishes the shared encryption key as an output in its remote state.
# The backend settings are placeholders: the grader never reads a real state file.
data "terraform_remote_state" "platform" {
  backend = "s3"
  config = {
    bucket = "hx-lab20-platform-state"
    key    = "platform/terraform.tfstate"
    region = "us-east-1"
  }
}

# TODO(task 1): this bucket used to be aws_s3_bucket.ledger in the real state. The rename below
#               would make the next plan destroy the old bucket and create a new one. Tell
#               Terraform it is the same object with a moved block.
resource "aws_s3_bucket" "archive" {
  bucket = "hx-lab20-ledger-archive"
}

# TODO(task 2a): keep every object version. "Suspended" lets an overwrite destroy history.
resource "aws_s3_bucket_versioning" "archive" {
  bucket = aws_s3_bucket.archive.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "archive" {
  bucket = aws_s3_bucket.archive.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
      # TODO(task 2b): this key ARN was pasted from the platform stack's output last quarter.
      #                Read it from the platform remote state so a key rotation follows.
      kms_master_key_id = "arn:aws:kms:us-east-1:123456789012:key/pasted-last-quarter"
    }
  }
}

output "archive_bucket" {
  value = aws_s3_bucket.archive.bucket
}
