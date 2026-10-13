data "aws_caller_identity" "current" {}

locals {
  # Convención de nombres: <proyecto>-<ambiente>-<componente>
  name       = "${var.project}-${var.environment}"
  stage_name = var.environment
}


# ═══ API: API Gateway REST ════════════════════════════════════════════════════

module "rest_api" {
  source = "./modules/api_gateway_rest_api"

  rest_api_name   = "${local.name}-api"
  api_description = "Demo API"
}

# /api → solo segmento intermedio (sin métodos)
module "route_api" {
  source = "./modules/api_gateway_route"

  rest_api_id        = module.rest_api.api_gateway_id
  parent_resource_id = module.rest_api.rest_api_root_resource_id
  path               = "api"
  methods            = []
}

# /api/visits → GET y POST hacia la Lambda
module "route_visits" {
  source = "./modules/api_gateway_route"

  rest_api_id        = module.rest_api.api_gateway_id
  parent_resource_id = module.route_api.resource_id
  path               = "visits"
  methods            = ["GET", "POST"]
  integration_type   = "AWS_PROXY"
  lambda_invoke_arn  = module.api_lambda.invoke_arn
}

module "api_deployment" {
  source = "./modules/api_gateway_deployment"

  rest_api_id = module.rest_api.api_gateway_id
  stage_name  = local.stage_name

  # Fuerza un nuevo deployment cuando cambian las rutas.
  deployment_triggers = {
    redeployment = sha1(jsonencode([
      module.route_api.resource_id,
      module.route_visits.method_ids,
      module.route_visits.integration_ids,
    ]))
  }

  depends_on = [module.route_visits]
}

# ═══ Capa de cómputo ══════════════════════════════════════════════════════════

data "archive_file" "api" {
  type        = "zip"
  source_dir  = "${path.root}/src/api"
  output_path = "${path.root}/.build/api.zip"
}

module "api_lambda" {
  source = "./modules/lambda_function"

  function_name = "${local.name}-api"
  description   = "Contador de visitas de la demo"
  runtime       = "nodejs22.x"
  architectures = ["arm64"]
  source_path   = data.archive_file.api.output_path
  memory_size   = 128
  timeout       = 5

  environment_variables = {
    TABLE_NAME     = module.visits_table.table_name
    MESSAGE        = var.message
    ALLOWED_ORIGIN = local.site_url # CORS: el frontend se sirve desde otro dominio
  }

  # Mínimo privilegio: solo las dos acciones que usa, solo sobre su tabla.
  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["dynamodb:GetItem", "dynamodb:UpdateItem"]
      Resource = [module.visits_table.table_arn]
    }]
  })

  invoke_permissions = {
    AllowApiGatewayInvoke = {
      principal  = "apigateway.amazonaws.com"
      source_arn = "${module.rest_api.api_gateway_execution_arn}/*/*"
    }
  }

  log_retention_in_days = 14
}

# ═══ Capa de datos ════════════════════════════════════════════════════════════

module "visits_table" {
  source = "./modules/dynamo_table"

  table_name = "${local.name}-visits"
  hash_key   = "pk"
  attributes = [{ name = "pk", type = "S" }]

  # null = llave administrada por AWS (aws/dynamodb). En producción, usa una CMK.
  kms_dynamodb_arn = null
}
# ═══ Capa de borde: S3 static website hosting ════════════════════════════════

module "site_bucket" {
  source = "./modules/s3"

  enabled             = true
  bucket_name         = "${local.name}-site-${data.aws_caller_identity.current.account_id}"
  enabled_website     = true
  cors_enabled        = false
  block_public_access = false

  kms_key_arn = null # SSE-S3

  # Solo para la demo: destroy borra el bucket con todos sus objetos y versiones.
  force_destroy = true
}

locals {
  content_types = {
    html = "text/html; charset=utf-8"
    css  = "text/css"
    js   = "application/javascript"
    json = "application/json"
    svg  = "image/svg+xml"
    png  = "image/png"
    ico  = "image/x-icon"
  }
  site_dir = "${path.root}/src/web"
  site_url = "http://${module.site_bucket.s3_website_endpoint}"
}

resource "aws_s3_object" "site" {
  for_each = fileset(local.site_dir, "**")

  bucket       = module.site_bucket.s3_name
  key          = each.value
  source       = "${local.site_dir}/${each.value}"
  etag         = filemd5("${local.site_dir}/${each.value}")
  content_type = lookup(local.content_types, lower(regex("[^.]+$", each.value)), "application/octet-stream")
}

# El frontend y la API viven en dominios distintos: la URL de la API se le
# entrega al frontend en este archivo, generado por Terraform.
resource "aws_s3_object" "site_config" {
  bucket       = module.site_bucket.s3_name
  key          = "config.js"
  content      = "window.API_URL = ${jsonencode(module.api_deployment.invoke_url)};\n"
  content_type = local.content_types.js
}

# La política se crea aquí y no con la variable bucket_policy del módulo s3:
# depende del ARN del bucket, que solo se conoce después del apply, y el
# módulo usa ese valor para decidir su count.
data "aws_iam_policy_document" "site_bucket" {
  statement {
    sid       = "PublicRead"
    actions   = ["s3:GetObject"]
    resources = ["${module.site_bucket.s3_arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = module.site_bucket.s3_name
  policy = data.aws_iam_policy_document.site_bucket.json

  # S3 rechaza una política pública mientras el bloqueo de acceso público siga activo.
  depends_on = [module.site_bucket]
}
