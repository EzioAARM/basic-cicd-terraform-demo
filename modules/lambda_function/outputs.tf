output "function_arn" {
  description = "ARN de la función Lambda"
  value       = var.enabled ? aws_lambda_function.this[0].arn : ""
}

output "qualified_arn" {
  description = "ARN cualificado (con versión) de la función Lambda, necesario para asociar a CloudFront (Lambda@Edge)"
  value       = var.enabled ? aws_lambda_function.this[0].qualified_arn : ""
}

output "function_name" {
  description = "Nombre de la función Lambda"
  value       = var.enabled ? aws_lambda_function.this[0].function_name : ""
}

output "version" {
  description = "Última versión publicada de la función"
  value       = var.enabled ? aws_lambda_function.this[0].version : ""
}

output "role_arn" {
  description = "ARN del rol IAM de la función Lambda"
  value       = local.role_arn
}

output "role_name" {
  description = "Nombre del rol IAM creado por el módulo (vacío si se pasó role_arn)"
  value       = local.create_role ? aws_iam_role.lambda_role[0].name : ""
}

output "invoke_arn" {
  description = "ARN de invocación de la función Lambda (para integración con API Gateway)"
  value       = var.enabled ? aws_lambda_function.this[0].invoke_arn : ""
}

output "log_group_name" {
  description = "Nombre del CloudWatch Log Group de la función (vacío si create_log_group = false)"
  value       = var.enabled && var.create_log_group ? aws_cloudwatch_log_group.lambda[0].name : ""
}
