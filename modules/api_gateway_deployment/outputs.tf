output "deployment_id" {
  description = "The ID of the API Gateway deployment"
  value       = aws_api_gateway_deployment.this.id
}

output "stage_name" {
  description = "The name of the API Gateway stage"
  value       = aws_api_gateway_stage.this.stage_name
}

output "invoke_url" {
  description = "The invoke URL of the API Gateway stage"
  value       = aws_api_gateway_stage.this.invoke_url
}
