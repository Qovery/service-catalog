# -----------------------------------------------------------------------------
# AWS S3 Bucket
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "this" {
  bucket        = lower(var.bucket_name)
  force_destroy = var.force_destroy

  tags = {
    ManagedBy   = "terraform"
    Service     = "s3"
    ClusterName = var.qovery_cluster_name

    # Native-parity Qovery context tags, filled from the qbm.yml context variables.
    cluster_id      = var.qovery_cluster_id
    cluster_long_id = var.qovery_cluster_long_id
    region          = var.region
  }
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = var.versioning ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  count  = var.encryption ? 1 : 0
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
