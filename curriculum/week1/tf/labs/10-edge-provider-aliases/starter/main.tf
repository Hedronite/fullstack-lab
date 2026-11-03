# Hedronite lab 10 starter: an edge release-artifacts bucket and its replica in a second
# region. Valid HCL, wrong behaviour on purpose. See ../README.md for the tasks.

resource "aws_s3_bucket" "releases" {
  bucket = "hx-lab10-edge-releases"
}

resource "aws_s3_bucket" "releases_dr" {
  # TODO(task 1): this bucket must live in the second region, through the aliased
  #               provider. As written it silently lands in the primary region.
  bucket = "hx-lab10-edge-releases-dr"
}

output "release_buckets" {
  value = [aws_s3_bucket.releases.bucket, aws_s3_bucket.releases_dr.bucket]
}
