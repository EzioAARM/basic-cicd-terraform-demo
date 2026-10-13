# Mismos nombres de outputs que api_gateway_internal_alb, para que los
# consumidores (api_gateway_route, permisos de Lambda) funcionen igual.

output "api_gateway_id" {
  description = "ID del API Gateway REST API"
  value       = aws_api_gateway_rest_api.this.id
}

output "api_gateway_execution_arn" {
  description = "Execution ARN del API Gateway (para permisos Lambda)"
  value       = aws_api_gateway_rest_api.this.execution_arn
}

output "rest_api_root_resource_id" {
  description = "ID del recurso raíz del API Gateway (para agregar más recursos)"
  value       = aws_api_gateway_rest_api.this.root_resource_id
}

output "execute_api_domain" {
  description = "Dominio execute-api del REST API (para usarlo como origen en CloudFront)"
  value       = "${aws_api_gateway_rest_api.this.id}.execute-api.${data.aws_region.current.region}.amazonaws.com"
}
