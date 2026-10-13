variable "name" {
  description = "Nombre de la distribución (se usa en el comment y en el OAC)."
  type        = string
}

variable "s3_origin_domain_name" {
  description = "bucket_regional_domain_name del bucket privado con el contenido estático."
  type        = string
}

variable "api_origin_domain_name" {
  description = "Dominio del API (sin https://). null = distribución solo con S3."
  type        = string
  default     = null
}

variable "api_origin_path" {
  description = "Prefijo que CloudFront agrega al reenviar al API (p.ej. '/dev' para el stage de un REST API)."
  type        = string
  default     = ""
}

variable "api_path_pattern" {
  description = "Rutas que se envían al API en lugar de S3."
  type        = string
  default     = "/api/*"
}

variable "default_root_object" {
  description = "Objeto que se sirve al pedir la raíz (/)."
  type        = string
  default     = "index.html"
}

variable "price_class" {
  description = "Ubicaciones de CloudFront. PriceClass_100 es la más económica."
  type        = string
  default     = "PriceClass_100"

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.price_class)
    error_message = "price_class debe ser PriceClass_100, PriceClass_200 o PriceClass_All."
  }
}

variable "tags" {
  description = "Tags a aplicar a la distribución"
  type        = map(string)
  default     = {}
}
