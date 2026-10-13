output "s3_arn" {
  value = var.enabled ? aws_s3_bucket.this[0].arn : null
}

output "s3_name" {
  value = var.enabled ? aws_s3_bucket.this[0].id : null
}

output "s3_bucket_regional_domain_name" {
  description = "Dominio regional del bucket (para usarlo como origen en CloudFront)."
  value       = var.enabled ? aws_s3_bucket.this[0].bucket_regional_domain_name : null
}

output "s3_website_endpoint" {
  description = "Endpoint de static website hosting (solo HTTP). null si enabled_website = false."
  value       = var.enabled_website ? aws_s3_bucket_website_configuration.example[0].website_endpoint : null
}
