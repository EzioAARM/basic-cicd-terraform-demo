terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

locals {
  create_role = var.enabled && var.role_arn == ""
  role_arn    = var.role_arn != "" ? var.role_arn : (local.create_role ? aws_iam_role.lambda_role[0].arn : "")

  # Lambda@Edge requiere publicar versión y necesita edgelambda en el trust.
  publish = var.is_edge ? true : var.publish

  # Principals que pueden asumir el rol de ejecución.
  assume_role_services = var.is_edge ? [
    "lambda.amazonaws.com",
    "edgelambda.amazonaws.com",
  ] : ["lambda.amazonaws.com"]

  # Si la función corre en VPC necesita permisos de ENI. Lambda@Edge no soporta VPC.
  in_vpc = length(var.vpc_subnet_ids) > 0

  vpc_execution_policy = local.in_vpc ? [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  ] : []

  # Políticas gestionadas a adjuntar al rol creado: básica de ejecución + VPC
  # (si aplica) + las extra que pase el usuario. Se usa un set para el for_each
  # de los attachments (evita el argumento deprecado managed_policy_arns).
  managed_policy_arns = local.create_role ? distinct(concat(
    ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"],
    local.vpc_execution_policy,
    var.managed_policy_arns
  )) : []
}

# ========================================
# IAM Role
# ========================================

resource "aws_iam_role" "lambda_role" {
  count = local.create_role ? 1 : 0

  name = "${var.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = local.assume_role_services
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

# Políticas gestionadas adjuntas al rol. Se usan attachments separados en lugar
# del argumento inline managed_policy_arns (deprecado en el provider AWS).
resource "aws_iam_role_policy_attachment" "managed" {
  for_each = toset(local.managed_policy_arns)

  role       = aws_iam_role.lambda_role[0].name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "inline" {
  count = local.create_role && var.policy_json != "" ? 1 : 0

  name   = "${var.function_name}-inline"
  role   = aws_iam_role.lambda_role[0].id
  policy = var.policy_json
}

# ========================================
# CloudWatch Log Group
# ========================================
# Se crea explícitamente para controlar la retención. En Lambda@Edge los logs
# se generan por región (/aws/lambda/us-east-1.<name>), por eso create_log_group
# debe ir en false para funciones @Edge.

resource "aws_cloudwatch_log_group" "lambda" {
  count = var.enabled && var.create_log_group ? 1 : 0

  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_in_days
  kms_key_id        = var.kms_key_arn != "" ? var.kms_key_arn : null

  tags = var.tags
}

# ========================================
# Lambda Function
# ========================================

resource "aws_lambda_function" "this" {
  count = var.enabled ? 1 : 0

  function_name = var.function_name
  description   = var.description
  role          = local.role_arn
  handler       = var.handler
  runtime       = var.runtime
  architectures = var.architectures
  memory_size   = var.memory_size
  timeout       = var.timeout
  publish       = local.publish
  layers        = var.layers

  kms_key_arn = var.kms_key_arn != "" ? var.kms_key_arn : null

  reserved_concurrent_executions = var.reserved_concurrent_executions

  filename         = var.source_path
  source_code_hash = filebase64sha256(var.source_path)

  lifecycle {
    ignore_changes = [
      filename,
      source_code_hash,
    ]
  }

  dynamic "environment" {
    for_each = length(var.environment_variables) > 0 ? [1] : []
    content {
      variables = var.environment_variables
    }
  }

  dynamic "ephemeral_storage" {
    for_each = var.ephemeral_storage_size != 512 ? [1] : []
    content {
      size = var.ephemeral_storage_size
    }
  }

  dynamic "vpc_config" {
    for_each = local.in_vpc ? [1] : []
    content {
      subnet_ids         = var.vpc_subnet_ids
      security_group_ids = var.vpc_security_group_ids
    }
  }

  dynamic "tracing_config" {
    for_each = var.tracing_mode != "" ? [1] : []
    content {
      mode = var.tracing_mode
    }
  }

  dynamic "dead_letter_config" {
    for_each = var.dead_letter_target_arn != "" ? [1] : []
    content {
      target_arn = var.dead_letter_target_arn
    }
  }

  # Asegura que el log group exista con su retención antes que la función.
  depends_on = [aws_cloudwatch_log_group.lambda]

  tags = var.tags
}

# ========================================
# Permisos de invocación (triggers)
# ========================================

resource "aws_lambda_permission" "this" {
  for_each = var.enabled ? var.invoke_permissions : {}

  statement_id   = each.key
  action         = coalesce(each.value.action, "lambda:InvokeFunction")
  function_name  = aws_lambda_function.this[0].function_name
  principal      = each.value.principal
  source_arn     = each.value.source_arn
  source_account = each.value.source_account
}
