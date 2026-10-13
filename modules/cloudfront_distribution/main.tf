# ─────────────────────────────────────────────────────────────────────────────
# cloudfront_distribution
#   Distribución CloudFront con:
#     - Origen S3 privado vía Origin Access Control (OAC) para el contenido estático.
#     - Origen API opcional (API Gateway) bajo api_path_pattern, sin caché.
#   La política del bucket que autoriza a CloudFront se crea en el proyecto,
#   usando el output distribution_arn.
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

locals {
  with_api = var.api_origin_domain_name != null
}

resource "aws_cloudfront_origin_access_control" "this" {
  name                              = "${var.name}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Políticas administradas por AWS (se buscan por nombre).
data "aws_cloudfront_cache_policy" "optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_cache_policy" "disabled" {
  name = "Managed-CachingDisabled"
}

# API Gateway rechaza el header Host del visitante: se reenvía todo excepto ese.
data "aws_cloudfront_origin_request_policy" "api" {
  name = "Managed-AllViewerExceptHostHeader"
}

# HSTS, X-Content-Type-Options, X-Frame-Options, Referrer-Policy, etc.
data "aws_cloudfront_response_headers_policy" "security" {
  name = "Managed-SecurityHeadersPolicy"
}

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  comment             = var.name
  default_root_object = var.default_root_object
  price_class         = var.price_class
  http_version        = "http2and3"

  origin {
    origin_id                = "s3"
    domain_name              = var.s3_origin_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
  }

  dynamic "origin" {
    for_each = local.with_api ? [1] : []
    content {
      origin_id   = "api"
      domain_name = var.api_origin_domain_name
      origin_path = var.api_origin_path

      custom_origin_config {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }
    }
  }

  default_cache_behavior {
    target_origin_id           = "s3"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    cache_policy_id            = data.aws_cloudfront_cache_policy.optimized.id
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.security.id
    compress                   = true
  }

  dynamic "ordered_cache_behavior" {
    for_each = local.with_api ? [1] : []
    content {
      path_pattern             = var.api_path_pattern
      target_origin_id         = "api"
      viewer_protocol_policy   = "https-only"
      allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
      cached_methods           = ["GET", "HEAD"]
      cache_policy_id          = data.aws_cloudfront_cache_policy.disabled.id
      origin_request_policy_id = data.aws_cloudfront_origin_request_policy.api.id
      compress                 = true
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = var.tags
}
