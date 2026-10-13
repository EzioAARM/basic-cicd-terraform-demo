variable "rest_api_id" {
  description = "ID del API Gateway REST API"
  type        = string
}

variable "parent_resource_id" {
  description = "ID del recurso padre (normalmente el root_resource_id del API Gateway)"
  type        = string
}

variable "path" {
  description = "Path de la ruta (e.g. 'login', 'user/create', '{proxy+}'). No incluir el slash inicial."
  type        = string
}

variable "methods" {
  description = "Lista de métodos HTTP para esta ruta (e.g. ['ANY'], ['GET', 'POST']). Vacío si solo se crea el segmento sin métodos."
  type        = list(string)
  default     = ["ANY"]
}

variable "authorization" {
  description = "Tipo de autorización: NONE, COGNITO_USER_POOLS, CUSTOM, AWS_IAM"
  type        = string
  default     = "NONE"
}

variable "authorizer_id" {
  description = "ID del authorizer (requerido si authorization != NONE)"
  type        = string
  default     = null
}

variable "integration_type" {
  description = "Tipo de integración: HTTP_PROXY (backend vía VPC Link) o AWS_PROXY (Lambda)."
  type        = string
  default     = "HTTP_PROXY"

  validation {
    condition     = contains(["HTTP_PROXY", "AWS_PROXY"], var.integration_type)
    error_message = "integration_type debe ser HTTP_PROXY o AWS_PROXY."
  }
}

variable "vpc_link_id" {
  description = "ID del VPC Link para la integración (requerido con HTTP_PROXY)."
  type        = string
  default     = null

  validation {
    condition     = var.integration_type != "HTTP_PROXY" || var.vpc_link_id != null || length(var.methods) == 0
    error_message = "vpc_link_id es requerido cuando integration_type = HTTP_PROXY y hay métodos."
  }
}

variable "backend_uri" {
  description = "URI base del backend (e.g. 'http://internal-alb-dns.com'). La ruta se agrega automáticamente. Requerido con HTTP_PROXY."
  type        = string
  default     = ""
}

variable "lambda_invoke_arn" {
  description = "invoke_arn de la Lambda (requerido con AWS_PROXY)."
  type        = string
  default     = null

  validation {
    condition     = var.integration_type != "AWS_PROXY" || var.lambda_invoke_arn != null || length(var.methods) == 0
    error_message = "lambda_invoke_arn es requerido cuando integration_type = AWS_PROXY y hay métodos."
  }
}

variable "is_proxy_route" {
  description = "Si es true, configura la ruta como proxy pass-through con path parameter mapping ({proxy+})"
  type        = bool
  default     = false
}

variable "authorization_scopes" {
  description = "Lista de scopes OAuth requeridos (solo aplica con authorization = COGNITO_USER_POOLS). Vacío para no exigir scopes."
  type        = list(string)
  default     = []
}

variable "integration_http_method" {
  description = "Método HTTP usado hacia el backend en la integración. Si vacío, usa el mismo método del request (o ANY). Las rutas existentes lo fijan en POST."
  type        = string
  default     = ""
}

variable "integration_request_parameters" {
  description = <<-EOT
    request_parameters extra para la integración (además del mapping de proxy).
    Se fusiona con el mapping automático de {proxy}. Ejemplo para fijar el Host:
      { "integration.request.header.Host" = "'api-dev.example.com'" }
  EOT
  type        = map(string)
  default     = {}
}

variable "passthrough_behavior" {
  description = "passthrough_behavior de la integración (WHEN_NO_MATCH, WHEN_NO_TEMPLATES, NEVER)."
  type        = string
  default     = "WHEN_NO_MATCH"
}

variable "timeout_milliseconds" {
  description = "Timeout de la integración en milisegundos."
  type        = number
  default     = 29000
}

variable "create_resource" {
  description = "Si es true, crea el aws_api_gateway_resource. Si es false, se usa parent_resource_id directamente como resource_id (para métodos sobre recursos ya existentes como el root o segmentos intermedios ya creados)."
  type        = bool
  default     = true
}
