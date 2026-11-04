# Hedronite lab 11 (import and remote state) grader.
# Staged as tests/hedronite_grader.tftest.hcl by curriculum/week1/tf/stage.sh.
# Offline by construction: mock_provider means no cloud credentials, no cloud calls, no cost.
# Needs Terraform >= 1.7 for mock_provider and override_*; the lab pins 1.10.5 (the lab image).
#
# What it sees: the plan graph after a mock apply. It cannot see import, moved or backend
# blocks (a mock provider cannot import, a test has no prior state, backends are skipped), so
# check.sh checks tasks 1, 2 and 3 statically. Task 4 is graded here: the platform
# configuration's state is replaced by override_data, and the artifacts bucket must take its
# name from that root output.

mock_provider "aws" {
  mock_resource "aws_s3_bucket" {
    defaults = {
      arn = "arn:aws:s3:::hx-mock"
    }
  }
}

# Stands in for the platform team's state snapshot; no S3 read happens.
override_data {
  target = data.terraform_remote_state.platform
  values = {
    outputs = {
      release_bucket_name = "hx-mock-from-remote-state"
    }
  }
}

# A mock provider cannot import, so the imported bucket is overridden with the values the real
# import would read. Without this override a correct import block would fail the test itself.
override_resource {
  target = aws_s3_bucket.legacy_logs
  values = {
    id  = "hx-lab11-legacy-logs"
    arn = "arn:aws:s3:::hx-lab11-legacy-logs"
  }
}

run "buckets_use_the_right_names" {
  command = apply

  assert {
    condition     = aws_s3_bucket.legacy_logs.bucket == "hx-lab11-legacy-logs"
    error_message = "The adopted bucket must keep the name of the real bucket, hx-lab11-legacy-logs."
  }

  assert {
    condition     = aws_s3_bucket.artifacts.bucket == "hx-mock-from-remote-state"
    error_message = "Task 4: the artifacts bucket name is typed in by hand. Read it from data.terraform_remote_state.platform.outputs.release_bucket_name."
  }
}
