variable "region" {
  description = "Región de AWS"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Nombre corto del proyecto (prefijo de todos los recursos)"
  type        = string
  default     = "demo"
}

variable "environment" {
  description = "Ambiente"
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Responsable de los recursos (tag Owner)"
  type        = string
}

variable "message" {
  description = "Mensaje que muestra la app"
  type        = string
  default     = "¡Hola! Esta arquitectura se creó con Terraform"
}
