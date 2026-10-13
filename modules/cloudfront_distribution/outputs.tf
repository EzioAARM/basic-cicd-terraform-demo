output "distribution_id" {
  description = "ID de la distribución (útil para invalidar caché)"
  value       = aws_cloudfront_distribution.this.id
}

output "distribution_arn" {
  description = "ARN de la distribución (para la política del bucket S3)"
  value       = aws_cloudfront_distribution.this.arn
}

output "domain_name" {
  description = "Dominio *.cloudfront.net de la distribución"
  value       = aws_cloudfront_distribution.this.domain_name
}
