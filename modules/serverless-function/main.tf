terraform {
  required_version = ">= 1.9"

  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

variable "function_name" {
  description = "Name of the function."
  type        = string
}

variable "runtime" {
  description = "Language runtime."
  type        = string
  default     = "nodejs22"

  validation {
    condition     = contains(["nodejs22", "python3.13", "go1.25"], var.runtime)
    error_message = "runtime must be nodejs22, python3.13 or go1.25."
  }
}

variable "memory_mb" {
  description = "Memory given to each invocation."
  type        = number
  default     = 256

  validation {
    condition     = contains([128, 256, 512, 1024, 2048], var.memory_mb)
    error_message = "memory_mb must be 128, 256, 512, 1024 or 2048."
  }
}

variable "environment" {
  description = "Environment variables the function sees."
  type        = map(string)
  default = {
    LOG_LEVEL = "info"
  }
}

variable "greeting" {
  description = "What the function answers with. Changing it ships a new version."
  type        = string
  default     = "hello from openplan"
}

data "archive_file" "source" {
  type        = "zip"
  output_path = "${path.module}/${var.function_name}.zip"

  source {
    filename = "index.js"
    content  = <<-JS
      export const handler = async () => ({
        statusCode: 200,
        body: JSON.stringify({ message: ${jsonencode(var.greeting)} }),
      });
    JS
  }
}

resource "terraform_data" "function" {
  input = {
    name        = var.function_name
    runtime     = var.runtime
    memory_mb   = var.memory_mb
    environment = var.environment
    source_hash = data.archive_file.source.output_base64sha256
  }
}

resource "terraform_data" "http_trigger" {
  input = {
    function = terraform_data.function.output.name
    url      = "https://${var.function_name}.fn.demo.example/"
  }
}

output "url" {
  description = "Where the function answers HTTP requests."
  value       = terraform_data.http_trigger.output.url
}

output "package_size_bytes" {
  description = "Size of the deployed archive."
  value       = data.archive_file.source.output_size
}
