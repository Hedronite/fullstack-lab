# Hedronite lab 11 starter: the edge service's buckets after a hand-made bucket, a rename and a
# move to remote state. Valid HCL, wrong behaviour on purpose. See ../README.md for the tasks.

# The platform team's configuration publishes the release bucket name as a root output.
data "terraform_remote_state" "platform" {
  backend = "s3"

  config = {
    bucket = "hx-lab11-state"
    key    = "platform/terraform.tfstate"
    region = var.region
  }
}

# TODO(task 1): this bucket already exists. Someone created it by hand in the console, and
#               this configuration was written to match it. Bring the real bucket under
#               management (id "hx-lab11-legacy-logs") instead of letting apply try to create it.
resource "aws_s3_bucket" "legacy_logs" {
  bucket = "hx-lab11-legacy-logs"
}

# TODO(task 2): this resource used to be aws_s3_bucket.releases and the state still records it
#               at that address. As written, the next plan destroys the old bucket and creates
#               a new one.
# TODO(task 4): the bucket name is typed in by hand. Read it from the platform team's root
#               output release_bucket_name instead.
resource "aws_s3_bucket" "artifacts" {
  bucket = "hx-lab11-edge-releases"
}

output "edge_buckets" {
  value = [aws_s3_bucket.legacy_logs.bucket, aws_s3_bucket.artifacts.bucket]
}
