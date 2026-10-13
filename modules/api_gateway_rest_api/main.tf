# ─────────────────────────────────────────────────────────────────────────────
# api_gateway_rest_api
#   Crea únicamente el REST API (sin VPC Link ni NLB). Las rutas se definen con
#   api_gateway_route y el deployment + stage con api_gateway_deployment.
#   Para backends privados (ALB interno) usa api_gateway_internal_alb.
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

data "aws_region" "current" {}

resource "aws_api_gateway_rest_api" "this" {
  name        = var.rest_api_name
  description = var.api_description

  endpoint_configuration {
    types = [var.api_gateway_type]
  }

  tags = var.tags
}
