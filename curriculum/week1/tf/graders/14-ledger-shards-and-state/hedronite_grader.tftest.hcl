# Hedronite lab 14 (ledger shards and state) grader.
# Offline by construction: mock_provider means no cloud credentials, no cloud calls, no cost.
# Needs Terraform >= 1.7 for mock_provider and override_resource; the lab pins 1.10.5 (the lab image).
#
# What it sees: the plan graph after a mock apply. It grades task 1 (the shard set has all three
# real buckets). A mock provider cannot import, a test has no prior state and backends are
# skipped, so check.sh checks tasks 2 (import with for_each), 3 (removed block) and 4 (partial
# backend configuration with native locking) statically on the .tf text and the backend file.

mock_provider "aws" {
  mock_resource "aws_s3_bucket" {
    defaults = {
      arn = "arn:aws:s3:::hx-mock"
    }
  }
}

# A mock provider cannot import, so each adopted shard is overridden with the values the real
# import would read. Without these a correct import block would fail the test itself.
override_resource {
  target = aws_s3_bucket.shard["a"]
  values = {
    id  = "hx-lab14-a"
    arn = "arn:aws:s3:::hx-lab14-a"
  }
}

override_resource {
  target = aws_s3_bucket.shard["b"]
  values = {
    id  = "hx-lab14-b"
    arn = "arn:aws:s3:::hx-lab14-b"
  }
}

override_resource {
  target = aws_s3_bucket.shard["c"]
  values = {
    id  = "hx-lab14-c"
    arn = "arn:aws:s3:::hx-lab14-c"
  }
}

run "all_three_shards_are_managed" {
  command = apply

  assert {
    condition     = length(aws_s3_bucket.shard) == 3
    error_message = "Task 1: the account holds three shard buckets (a, b and c) but the configuration manages ${length(aws_s3_bucket.shard)}. Add the missing shard to var.shards."
  }

  assert {
    condition     = toset(output.shard_buckets) == toset(["hx-lab14-a", "hx-lab14-b", "hx-lab14-c"])
    error_message = "Task 1: shard_buckets must list hx-lab14-a, hx-lab14-b and hx-lab14-c."
  }
}
