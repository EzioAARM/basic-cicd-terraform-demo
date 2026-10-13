output "resource_id" {
  description = "ID del recurso (creado o el padre si create_resource = false). Usar como parent_resource_id para rutas hijas."
  value       = local.resource_id
}

output "method_ids" {
  description = "Map de método HTTP -> ID del method resource"
  value       = { for k, v in aws_api_gateway_method.this : k => v.id }
}

output "integration_ids" {
  description = "Map de método HTTP -> ID del integration resource"
  value       = { for k, v in aws_api_gateway_integration.this : k => v.id }
}
