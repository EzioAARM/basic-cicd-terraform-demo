variable "enabled" {
  description = "Flag para habilitar o deshabilitar el módulo"
  type        = bool
  default     = true
}

variable "function_name" {
  description = "Nombre de la función Lambda"
  type        = string
}

variable "description" {
  description = "Descripción de la función Lambda"
  type        = string
  default     = ""
}

variable "runtime" {
  description = "Runtime de la función Lambda (ej: nodejs18.x, python3.12)"
  type        = string
  default     = "nodejs18.x"
}

variable "handler" {
  description = "Handler de la función Lambda"
  type        = string
  default     = "index.handler"
}

variable "architectures" {
  description = "Arquitecturas del set de instrucciones (x86_64 o arm64). Lambda@Edge solo soporta x86_64."
  type        = list(string)
  default     = ["x86_64"]

  validation {
    condition     = alltrue([for a in var.architectures : contains(["x86_64", "arm64"], a)])
    error_message = "Las arquitecturas válidas son x86_64 y arm64."
  }
}

variable "source_path" {
  description = "Ruta al archivo zip con el código de la función"
  type        = string
}

variable "memory_size" {
  description = "Memoria asignada a la función en MB (Lambda@Edge: max 128 para viewer, 10240 para origin)"
  type        = number
  default     = 128
}

variable "timeout" {
  description = "Timeout en segundos (Lambda@Edge: max 5 para viewer, 30 para origin)"
  type        = number
  default     = 5
}

variable "publish" {
  description = "Si se debe publicar una versión de la función (requerido para Lambda@Edge)"
  type        = bool
  default     = false
}

variable "is_edge" {
  description = "Si es true, configura la función como Lambda@Edge: agrega edgelambda.amazonaws.com al trust policy y fuerza el publicado de versión. Las funciones @Edge no soportan variables de entorno ni VPC."
  type        = bool
  default     = false
}

# ========================================
# IAM
# ========================================

variable "role_arn" {
  description = "ARN del rol IAM para la función Lambda. Si no se proporciona, se crea uno."
  type        = string
  default     = ""
}

variable "managed_policy_arns" {
  description = "Lista de ARNs de políticas gestionadas para el rol Lambda (se crea solo si role_arn está vacío)"
  type        = list(string)
  default     = []
}

variable "policy_json" {
  description = "JSON de una política IAM inline adicional a adjuntar al rol creado. Vacío = sin política inline. Solo aplica cuando role_arn está vacío."
  type        = string
  default     = ""
}

# ========================================
# Runtime config
# ========================================

variable "environment_variables" {
  description = "Variables de entorno para la función Lambda (no soportado en Lambda@Edge)"
  type        = map(string)
  default     = {}
}

variable "layers" {
  description = "Lista de ARNs de Lambda Layers a asociar a la función"
  type        = list(string)
  default     = []
}

variable "reserved_concurrent_executions" {
  description = "Concurrencia reservada para la función. -1 = sin límite (comportamiento por defecto de Lambda)."
  type        = number
  default     = -1
}

variable "ephemeral_storage_size" {
  description = "Tamaño del almacenamiento efímero /tmp en MB (512 a 10240)"
  type        = number
  default     = 512

  validation {
    condition     = var.ephemeral_storage_size >= 512 && var.ephemeral_storage_size <= 10240
    error_message = "El almacenamiento efímero debe estar entre 512 y 10240 MB."
  }
}

variable "kms_key_arn" {
  description = "ARN de la CMK para cifrar las variables de entorno. Vacío = clave gestionada por AWS."
  type        = string
  default     = ""
}

# ========================================
# VPC (no soportado en Lambda@Edge)
# ========================================

variable "vpc_subnet_ids" {
  description = "IDs de subnets para ejecutar la función dentro de una VPC. Vacío = sin VPC."
  type        = list(string)
  default     = []
}

variable "vpc_security_group_ids" {
  description = "IDs de security groups para la función cuando corre en VPC."
  type        = list(string)
  default     = []
}

# ========================================
# Observabilidad
# ========================================

variable "create_log_group" {
  description = "Si es true, crea el CloudWatch Log Group de la función con la retención indicada. Desactívalo para Lambda@Edge (los logs se generan por región)."
  type        = bool
  default     = true
}

variable "log_retention_in_days" {
  description = "Días de retención del CloudWatch Log Group de la función"
  type        = number
  default     = 30
}

variable "tracing_mode" {
  description = "Modo de tracing X-Ray: PassThrough, Active o vacío para desactivar."
  type        = string
  default     = ""

  validation {
    condition     = var.tracing_mode == "" || contains(["PassThrough", "Active"], var.tracing_mode)
    error_message = "tracing_mode debe ser PassThrough, Active o vacío."
  }
}

variable "dead_letter_target_arn" {
  description = "ARN de la cola SQS o topic SNS para la Dead Letter Queue. Vacío = sin DLQ."
  type        = string
  default     = ""
}

# ========================================
# Permisos de invocación (triggers)
# ========================================

variable "invoke_permissions" {
  description = <<-EOT
    Permisos de invocación (aws_lambda_permission) para servicios que invocan la
    función, p.ej. API Gateway, EventBridge o S3. La clave del mapa es el
    statement_id.
  EOT
  type = map(object({
    principal      = string           # p.ej. "apigateway.amazonaws.com"
    action         = optional(string) # por defecto "lambda:InvokeFunction"
    source_arn     = optional(string)
    source_account = optional(string)
  }))
  default = {}
}

variable "tags" {
  description = "Tags a aplicar a los recursos"
  type        = map(string)
  default     = {}
}
