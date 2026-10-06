terraform {
  required_version = ">= 1.9"
}

variable "pipeline_name" {
  description = "Name of the pipeline."
  type        = string
  default     = "platform-logs"
}

variable "sources" {
  description = "Where logs come from, and what share of each to keep."
  type        = map(number)
  default = {
    kubernetes    = 1
    load-balancer = 0.1
    audit         = 1
  }

  validation {
    condition     = alltrue([for rate in values(var.sources) : rate > 0 && rate <= 1])
    error_message = "Sample rates must be greater than 0 and at most 1."
  }
}

variable "processors" {
  description = "Processing steps, applied in order."
  type        = list(string)
  default     = ["parse-json", "drop-health-checks", "redact-emails", "add-environment"]
}

variable "sinks" {
  description = "Where processed logs are sent, and for how many days."
  type        = map(number)
  default = {
    hot-search   = 14
    cold-archive = 400
  }
}

resource "terraform_data" "source" {
  for_each = var.sources

  input = {
    name        = each.key
    sample_rate = each.value
  }
}

resource "terraform_data" "processor" {
  for_each = { for index, name in var.processors : name => index }

  input = {
    name  = each.key
    order = each.value + 1
  }

  depends_on = [terraform_data.source]
}

resource "terraform_data" "sink" {
  for_each = var.sinks

  input = {
    name           = each.key
    retention_days = each.value
  }

  depends_on = [terraform_data.processor]
}

resource "terraform_data" "pipeline" {
  input = {
    name  = var.pipeline_name
    graph = "${join("+", sort(keys(var.sources)))} -> ${join(" -> ", var.processors)} -> ${join("+", sort(keys(var.sinks)))}"
  }

  depends_on = [terraform_data.sink]
}

output "graph" {
  description = "The pipeline, from sources to sinks."
  value       = terraform_data.pipeline.output.graph
}
