# Hedronite lab 14 starter: the ledger shard buckets, created by hand over the last quarter.
# Valid HCL, wrong behaviour on purpose. See ../README.md for the tasks.

# TODO(task 2): the shard buckets already exist and are not in state, so the next plan wants
#               to create them. Adopt all of them with ONE import block that uses for_each
#               over var.shards (to = aws_s3_bucket.shard[each.key], id = hx-lab14-<shard>).
resource "aws_s3_bucket" "shard" {
  for_each = var.shards

  bucket = "hx-lab14-${each.key}"
}

# TODO(task 3): this scratch bucket is being handed to another team. Stop managing it
#               WITHOUT destroying the real bucket, as a reviewed change to the configuration:
#               delete this resource block and add a removed block that keeps the object.
resource "aws_s3_bucket" "scratch_ledger" {
  bucket = "hx-lab14-scratch"
}

output "shard_buckets" {
  value = [for b in aws_s3_bucket.shard : b.bucket]
}
