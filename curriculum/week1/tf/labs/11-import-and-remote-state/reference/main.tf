# Hedronite lab 11 reference: import block, moved block, native locking, root-output sharing
# (worked answer).

data "terraform_remote_state" "platform" {
  backend = "s3"

  config = {
    bucket = "hx-lab11-state"
    key    = "platform/terraform.tfstate"
    region = var.region
  }
}

# Task 1: adopt the hand-made bucket on the next apply, as a reviewable plan.
import {
  to = aws_s3_bucket.legacy_logs
  id = "hx-lab11-legacy-logs"
}

resource "aws_s3_bucket" "legacy_logs" {
  bucket = "hx-lab11-legacy-logs"
}

# Task 2: the object recorded at aws_s3_bucket.releases now lives at aws_s3_bucket.artifacts.
moved {
  from = aws_s3_bucket.releases
  to   = aws_s3_bucket.artifacts
}

# Task 4: the name comes from the platform configuration's root output.
resource "aws_s3_bucket" "artifacts" {
  bucket = data.terraform_remote_state.platform.outputs.release_bucket_name
}

output "edge_buckets" {
  value = [aws_s3_bucket.legacy_logs.bucket, aws_s3_bucket.artifacts.bucket]
}
