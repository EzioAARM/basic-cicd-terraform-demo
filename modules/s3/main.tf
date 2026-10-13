terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

data "aws_region" "current" {}

resource "aws_s3_bucket" "this" {

  count = var.enabled ? 1 : 0

  bucket        = var.bucket_name
  force_destroy = var.force_destroy

  tags = var.tags
}

resource "aws_s3_bucket_cors_configuration" "example" {

  count = var.cors_enabled ? 1 : 0

  bucket = aws_s3_bucket.this[0].id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = [
      "GET",
      "PUT",
      "POST",
      "DELETE",
      "HEAD"
    ]
    allowed_origins = [
      var.web_app_endpoint,
      "https://${var.web_app_endpoint}.transfer-webapp.${data.aws_region.current.region}.on.aws"
    ]
    expose_headers = [
      "last-modified",
      "content-length",
      "etag",
      "x-amz-version-id",
      "content-type",
      "x-amz-request-id",
      "x-amz-id-2",
      "date",
      "x-amz-cf-id",
      "x-amz-storage-class",
      "access-control-expose-headers"
    ]
    max_age_seconds = 3000
  }

}

resource "aws_s3_bucket_versioning" "this" {

  count = var.enabled ? 1 : 0

  bucket = aws_s3_bucket.this[count.index].id

  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {

  count = var.enabled ? 1 : 0

  bucket = aws_s3_bucket.this[count.index].id

  rule {
    # Con CMK usa SSE-KMS; sin CMK (null) usa SSE-S3 (AES256).
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn
    }

    # bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "this" {

  count = var.enabled ? 1 : 0

  bucket = aws_s3_bucket.this[count.index].id

  # Las ACL públicas siempre se bloquean: un sitio público se expone con política.
  block_public_acls       = true
  block_public_policy     = var.block_public_access
  ignore_public_acls      = true
  restrict_public_buckets = var.block_public_access
}

resource "aws_s3_bucket_website_configuration" "example" {

  count = var.enabled_website ? 1 : 0


  bucket = aws_s3_bucket.this[0].id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }

}

resource "aws_s3_bucket_policy" "this" {
  count = var.bucket_policy != null ? 1 : 0

  bucket = aws_s3_bucket.this[0].id
  policy = var.bucket_policy
}
