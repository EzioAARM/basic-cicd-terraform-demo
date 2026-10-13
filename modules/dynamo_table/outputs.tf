output "table_name" {
  description = "Nombre de la tabla creada (null si enabled = false)."
  value       = var.enabled ? aws_dynamodb_table.this[0].name : null
}

output "table_arn" {
  description = "ARN de la tabla creada (null si enabled = false)."
  value       = var.enabled ? aws_dynamodb_table.this[0].arn : null
}

output "table_id" {
  description = "ID de la tabla creada (null si enabled = false)."
  value       = var.enabled ? aws_dynamodb_table.this[0].id : null
}
