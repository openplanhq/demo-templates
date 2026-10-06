terraform {
  required_version = ">= 1.9"
}

variable "service_name" {
  description = "Name of the service."
  type        = string
}

variable "containers" {
  description = "Containers in the task. Exactly one should be essential."
  type = list(object({
    name      = string
    image     = string
    port      = optional(number)
    cpu       = optional(number, 256)
    memory_mb = optional(number, 512)
    essential = optional(bool, true)
  }))
  default = [
    { name = "app", image = "ghcr.io/acme/storefront:3.2.1", port = 8080 },
    { name = "log-router", image = "public.ecr.aws/aws-observability/aws-for-fluent-bit:stable", cpu = 64, memory_mb = 128, essential = false },
  ]

  validation {
    condition     = length([for container in var.containers : container if container.essential]) >= 1
    error_message = "At least one container must be essential."
  }
}

variable "desired_count" {
  description = "How many copies of the task to keep running."
  type        = number
  default     = 2
}

variable "log_retention_days" {
  description = "How long container logs are kept."
  type        = number
  default     = 14

  validation {
    condition     = contains([1, 3, 7, 14, 30, 90, 365], var.log_retention_days)
    error_message = "log_retention_days must be 1, 3, 7, 14, 30, 90 or 365."
  }
}

locals {
  task_definition = jsonencode({
    family = var.service_name
    containerDefinitions = [
      for container in var.containers : {
        name         = container.name
        image        = container.image
        cpu          = container.cpu
        memory       = container.memory_mb
        essential    = container.essential
        portMappings = container.port == null ? [] : [{ containerPort = container.port }]
      }
    ]
  })
}

resource "terraform_data" "log_group" {
  for_each = toset([for container in var.containers : container.name])

  input = {
    name           = "/services/${var.service_name}/${each.key}"
    retention_days = var.log_retention_days
  }
}

resource "terraform_data" "task_definition" {
  input = {
    family   = var.service_name
    revision = substr(sha256(local.task_definition), 0, 8)
    cpu      = sum([for container in var.containers : container.cpu])
    memory   = sum([for container in var.containers : container.memory_mb])
  }

  depends_on = [terraform_data.log_group]
}

resource "terraform_data" "service" {
  input = {
    name            = var.service_name
    task_definition = "${terraform_data.task_definition.output.family}:${terraform_data.task_definition.output.revision}"
    desired_count   = var.desired_count
  }
}

output "task_definition" {
  description = "The rendered task definition."
  value       = local.task_definition
}

output "task_size" {
  description = "CPU units and memory each task reserves."
  value       = "${terraform_data.task_definition.output.cpu} CPU / ${terraform_data.task_definition.output.memory} MiB"
}
