terraform {
  required_version = ">= 1.9"
}

variable "api_name" {
  description = "Name of the API."
  type        = string
  default     = "public-api"
}

variable "stage" {
  description = "Stage the routes are deployed to."
  type        = string
  default     = "v1"
}

variable "routes" {
  description = "Routes as \"METHOD /path\" mapped to the backend that serves them."
  type        = map(string)
  default = {
    "GET /orders"               = "http://orders.internal:8080"
    "POST /orders"              = "http://orders.internal:8080"
    "GET /orders/{id}"          = "http://orders.internal:8080"
    "GET /catalog/search"       = "http://search.internal:9200"
    "POST /webhooks/{provider}" = "http://hooks.internal:8081"
  }

  validation {
    condition     = alltrue([for route in keys(var.routes) : can(regex("^(GET|POST|PUT|PATCH|DELETE) /", route))])
    error_message = "Routes must look like \"GET /path\"."
  }
}

variable "usage_plans" {
  description = "Consumer tiers and the requests per second each may make."
  type        = map(number)
  default = {
    free     = 5
    standard = 50
    partner  = 500
  }
}

resource "terraform_data" "api" {
  input = {
    name     = var.api_name
    protocol = "HTTP"
  }
}

resource "terraform_data" "integration" {
  for_each = toset(values(var.routes))

  input = {
    api = terraform_data.api.output.name
    uri = each.key
  }
}

resource "terraform_data" "route" {
  for_each = var.routes

  input = {
    key         = each.key
    integration = terraform_data.integration[each.value].output.uri
  }
}

resource "terraform_data" "stage" {
  input = {
    name        = var.stage
    api         = terraform_data.api.output.name
    route_count = length(terraform_data.route)
  }
}

resource "terraform_data" "usage_plan" {
  for_each = var.usage_plans

  input = {
    name       = each.key
    stage      = terraform_data.stage.output.name
    rate_limit = each.value
    burst      = each.value * 2
  }
}

output "invoke_url" {
  description = "Base URL of the deployed stage."
  value       = "https://${var.api_name}.api.demo.example/${var.stage}"
}

output "backends" {
  description = "Distinct backends the routes reach."
  value       = sort(keys(terraform_data.integration))
}
