# Hedronite lab 10 reference: provider alias, version bound, no static keys (worked answer).

resource "aws_s3_bucket" "releases" {
  bucket = "hx-lab10-edge-releases"
}

resource "aws_s3_bucket" "releases_dr" {
  provider = aws.dr
  bucket   = "hx-lab10-edge-releases-dr"
}

output "release_buckets" {
  value = [aws_s3_bucket.releases.bucket, aws_s3_bucket.releases_dr.bucket]
}
