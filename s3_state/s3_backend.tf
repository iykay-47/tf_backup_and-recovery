resource "aws_s3_bucket" "s3_backend" {
  bucket = "backup-s3-remote-1576320"
  force_destroy = true

  lifecycle {
    prevent_destroy = true #Set to false when ready to destroy project
  }
}

resource "aws_s3_bucket_public_access_block" "s3_backend_BPA" {
  bucket = aws_s3_bucket.s3_backend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

}

resource "aws_s3_bucket_versioning" "s3_backend" {
  bucket = aws_s3_bucket.s3_backend.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "s3_backend" {
  bucket = aws_s3_bucket.s3_backend.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
