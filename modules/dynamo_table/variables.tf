variable "enabled" {
  description = "Crea la tabla cuando es true."
  type        = bool
  default     = true
}

variable "table_name" {
  description = "Nombre completo de la tabla DynamoDB (se arma en el proyecto con la convención de naming)."
  type        = string
}

variable "hash_key" {
  description = "Nombre del atributo usado como hash key (partition key)."
  type        = string
}

variable "range_key" {
  description = "Nombre del atributo usado como range key (sort key). Opcional."
  type        = string
  default     = null
}

variable "attributes" {
  description = "Atributos clave de la tabla (solo los usados por hash/range key o índices). type: S, N o B."
  type = list(object({
    name = string
    type = string
  }))
  validation {
    condition     = alltrue([for a in var.attributes : contains(["S", "N", "B"], a.type)])
    error_message = "Cada atributo debe tener type S (string), N (number) o B (binary)."
  }
}

variable "billing_mode" {
  description = "Modo de facturación: PAY_PER_REQUEST o PROVISIONED."
  type        = string
  default     = "PAY_PER_REQUEST"
  validation {
    condition     = contains(["PAY_PER_REQUEST", "PROVISIONED"], var.billing_mode)
    error_message = "billing_mode debe ser PAY_PER_REQUEST o PROVISIONED."
  }
}

variable "point_in_time_recovery" {
  description = "Habilita point-in-time recovery."
  type        = bool
  default     = true
}

variable "kms_dynamodb_arn" {
  description = "ARN de la KMS key (CMK) para el cifrado server-side de la tabla."
  type        = string
}

variable "tags" {
  description = "Tags a aplicar a la tabla."
  type        = map(string)
  default     = {}
}
