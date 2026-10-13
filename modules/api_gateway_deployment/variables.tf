variable "rest_api_id" {
  description = "The ID of the REST API"
  type        = string
}

variable "stage_name" {
  description = "The name of the stage"
  type        = string
}

variable "deployment_triggers" {
  description = "Triggers for the deployment (forces redeployment when values change)"
  type        = map(string)
  default     = {}
}

variable "depends_on_resources" {
  description = "List of resource identifiers for dependency tracking (use deployment_triggers instead, as depends_on cannot be used directly in modules)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to the API Gateway stage"
  type        = map(string)
  default     = {}
}
