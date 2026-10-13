variable "rest_api_name" {
  description = "Nombre del REST API (se arma en el proyecto con la convención de naming)."
  type        = string
}

variable "api_description" {
  description = "Descripción de la API REST"
  type        = string
  default     = "API REST"
}

variable "api_gateway_type" {
  description = "Tipo de endpoint. REGIONAL es el recomendado detrás de CloudFront."
  type        = string
  default     = "REGIONAL"

  validation {
    condition     = contains(["EDGE", "REGIONAL"], var.api_gateway_type)
    error_message = "Los tipos de endpoint permitidos son EDGE y REGIONAL (para PRIVATE usa api_gateway_internal_alb)."
  }
}

variable "tags" {
  description = "Tags a aplicar al REST API"
  type        = map(string)
  default     = {}
}
