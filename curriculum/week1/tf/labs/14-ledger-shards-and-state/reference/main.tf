# Hedronite lab 14 reference: one for_each import block, a removed block, partial backend
# configuration (worked answer).

# Task 2: adopt every shard bucket in a single reviewable plan.
import {
  for_each = var.shards

  to = aws_s3_bucket.shard[each.key]
  id = "hx-lab14-${each.key}"
}

resource "aws_s3_bucket" "shard" {
  for_each = var.shards

  bucket = "hx-lab14-${each.key}"
}

# Task 3: forget the scratch bucket, keep the real object.
removed {
  from = aws_s3_bucket.scratch_ledger

  lifecycle {
    destroy = false
  }
}

output "shard_buckets" {
  value = [for b in aws_s3_bucket.shard : b.bucket]
}
