# ─────────────────────────────────────────────────────────────────────────────
# api_gateway_route
#   Crea un único recurso (segmento) en API Gateway con sus métodos e
#   integraciones. Para rutas anidadas (/api/v1/users), encadena múltiples
#   instancias de este módulo usando el output resource_id como
#   parent_resource_id del siguiente nivel.
# ─────────────────────────────────────────────────────────────────────────────

locals {
  # AWS_PROXY = integración directa con Lambda; HTTP_PROXY = backend vía VPC Link.
  is_lambda = var.integration_type == "AWS_PROXY"

  http_integration_uri = var.is_proxy_route ? "${var.backend_uri}/{proxy}" : "${var.backend_uri}/${var.path}"
  integration_uri      = local.is_lambda ? var.lambda_invoke_arn : local.http_integration_uri

  # ID del recurso sobre el que se crean los métodos: el creado aquí o el padre
  # (cuando create_resource = false, p.ej. para métodos sobre el root u otro
  # segmento ya existente).
  resource_id = var.create_resource ? aws_api_gateway_resource.this[0].id : var.parent_resource_id

  # request_parameters del método: mapping de proxy (si aplica) + extras
  method_request_parameters = merge(
    var.is_proxy_route ? { "method.request.path.proxy" = true } : {},
  )

  # request_parameters de la integración: mapping de proxy (si aplica) + extras
  integration_request_parameters = merge(
    var.is_proxy_route ? { "integration.request.path.proxy" = "method.request.path.proxy" } : {},
    var.integration_request_parameters,
  )
}

# ─── Recurso (un solo segmento de path) ──────────────────────────────────────

resource "aws_api_gateway_resource" "this" {
  count = var.create_resource ? 1 : 0

  rest_api_id = var.rest_api_id
  parent_id   = var.parent_resource_id
  path_part   = var.path
}

# ─── Métodos e Integraciones ─────────────────────────────────────────────────

resource "aws_api_gateway_method" "this" {
  for_each = toset(var.methods)

  rest_api_id   = var.rest_api_id
  resource_id   = local.resource_id
  http_method   = each.value
  authorization = var.authorization
  authorizer_id = var.authorization != "NONE" ? var.authorizer_id : null

  authorization_scopes = var.authorization == "COGNITO_USER_POOLS" && length(var.authorization_scopes) > 0 ? var.authorization_scopes : null

  request_parameters = local.method_request_parameters
}

resource "aws_api_gateway_integration" "this" {
  for_each = toset(var.methods)

  rest_api_id = var.rest_api_id
  resource_id = local.resource_id
  http_method = aws_api_gateway_method.this[each.value].http_method

  type = var.integration_type

  # Lambda (AWS_PROXY) siempre se invoca con POST, sin importar el método del cliente.
  integration_http_method = local.is_lambda ? "POST" : (var.integration_http_method != "" ? var.integration_http_method : (each.value == "ANY" ? "ANY" : each.value))
  uri                     = local.integration_uri

  connection_type = local.is_lambda ? "INTERNET" : "VPC_LINK"
  connection_id   = local.is_lambda ? null : var.vpc_link_id

  passthrough_behavior = var.passthrough_behavior
  timeout_milliseconds = var.timeout_milliseconds

  request_parameters = local.integration_request_parameters
}
