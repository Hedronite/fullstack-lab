# Hedronite lab 13 starter: the S3 bucket that holds a deploy's action ledger. Valid HCL,
# wrong behaviour on purpose. See ../README.md for the tasks.

# TODO(task 2): this bucket used to be called aws_s3_bucket.soak_ledger and the state of
#               the running system still has it at that address. The rename below would
#               destroy and recreate it. Tell Terraform it is the same object.
resource "aws_s3_bucket" "ledger" {
  bucket = "hx-lab13-release-ledger"

  # A company tagging policy stamps `Owner` and `CostCenter` onto every bucket from outside
  # Terraform, and every plan now shows those tags being removed.
  # TODO(task 1b): tell Terraform to leave changes to `tags` alone on this resource.
  tags = {
    Service = "release-ledger"
  }
}

resource "aws_s3_bucket_versioning" "ledger" {
  bucket = aws_s3_bucket.ledger.id

  versioning_configuration {
    # TODO(task 1a): overwritten or deleted ledger objects are currently unrecoverable.
    status = "Suspended"
  }
}

output "ledger_bucket" {
  value = aws_s3_bucket.ledger.bucket
}
