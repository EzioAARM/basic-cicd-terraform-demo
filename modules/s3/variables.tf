variable "bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS CMK ARN used to encrypt S3 objects. null = SSE-S3 (AES256)."
  type        = string
}

variable "force_destroy" {
  description = "Permite borrar el bucket aunque tenga objetos (incluye todas las versiones). Solo para ambientes de prueba."
  type        = bool
  default     = false
}

variable "block_public_access" {
  description = "Bloquea las políticas públicas del bucket. Desactívalo solo para static website hosting."
  type        = bool
  default     = true
}

variable "versioning_enabled" {
  description = "Enable versioning for the bucket"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to the bucket"
  type        = map(string)
  default     = {}
}

variable "enabled" {
  type = bool
}

variable "enabled_website" {
  type = bool
}

variable "cors_enabled" {
  type = bool
}

variable "web_app_endpoint" {
  type    = string
  default = ""
}

variable "bucket_policy" {
  description = "Optional bucket policy JSON document. If null, no policy is created."
  type        = string
  default     = null
}