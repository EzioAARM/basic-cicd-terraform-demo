output "url" {
  description = "URL del frontend (S3 static website hosting)"
  value       = local.site_url
}

output "api_url" {
  description = "URL base de la API (stage de API Gateway)"
  value       = module.api_deployment.invoke_url
}
