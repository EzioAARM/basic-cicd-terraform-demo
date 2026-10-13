# lambda_function

Módulo genérico para desplegar funciones Lambda. Sirve tanto para funciones
normales (invocadas por API Gateway, EventBridge, S3, etc.) como para
Lambda@Edge, activando el modo con `is_edge = true`.

El código se empaqueta como zip y se referencia por `source_path`. El módulo
ignora cambios en el contenido del zip (`filename` / `source_code_hash`) para
que el ciclo de vida del código lo gestione el pipeline de despliegue, no
Terraform.

## Qué crea

- `aws_lambda_function` con soporte para variables de entorno, layers,
  arquitecturas (x86_64 / arm64), almacenamiento efímero, tracing X-Ray, DLQ,
  concurrencia reservada y cifrado con CMK.
- Rol IAM de ejecución (opcional, solo si no se pasa `role_arn`) con la política
  básica de Lambda, la de acceso a VPC cuando aplica, políticas gestionadas
  extra y una política inline opcional.
- CloudWatch Log Group con retención configurable (`create_log_group`).
- Permisos de invocación (`aws_lambda_permission`) para triggers como API
  Gateway o EventBridge (`invoke_permissions`).

## Notas sobre Lambda@Edge

Cuando `is_edge = true`:

- Se agrega `edgelambda.amazonaws.com` al trust policy del rol.
- Se fuerza `publish = true` (Edge requiere una versión publicada; usa
  `qualified_arn` para asociarla a CloudFront).
- No uses `environment_variables` ni VPC: Lambda@Edge no los soporta.
- Pon `create_log_group = false`: los logs se generan por región
  (`/aws/lambda/<region>.<function_name>`), no en un único log group.
- La función debe crearse en `us-east-1`.

## Ejemplo: función normal detrás de API Gateway

```hcl
module "mi_lambda" {
  source = "../../modules/lambda_function"

  function_name = "miapp-dev-worker"
  runtime       = "python3.12"
  handler       = "app.handler"
  source_path   = "${path.module}/src/lambda.zip"
  memory_size   = 256
  timeout       = 30

  environment_variables = {
    LOG_LEVEL = "INFO"
  }

  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["dynamodb:GetItem"]
      Resource = [module.mi_tabla.table_arn]
    }]
  })

  invoke_permissions = {
    apigw = {
      principal  = "apigateway.amazonaws.com"
      source_arn = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
    }
  }

  log_retention_in_days = 30
  tags                  = local.common_tags
}
```

## Ejemplo: Lambda@Edge

```hcl
module "edge" {
  source = "../../modules/lambda_function"

  providers = { aws = aws.us_east_1 }

  function_name    = "miapp-dev-viewer-request"
  runtime          = "nodejs18.x"
  handler          = "index.handler"
  source_path      = "${path.module}/src/lambda.zip"
  is_edge          = true
  create_log_group = false
  memory_size      = 128
  timeout          = 5
  tags             = local.common_tags
}

# Asociar con: module.edge.qualified_arn
```
