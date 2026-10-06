terraform {
  required_version = ">= 1.9"
}

variable "queue_name" {
  description = "Name of the job queue."
  type        = string
  default     = "nightly"
}

variable "max_vcpus" {
  description = "Most vCPUs the compute environment may run at once."
  type        = number
  default     = 64
}

variable "jobs" {
  description = "Jobs by name: image, resources and a cron schedule."
  type = map(object({
    image     = string
    vcpus     = number
    memory_mb = number
    schedule  = string
    retries   = optional(number, 1)
  }))
  default = {
    reindex-search = { image = "ghcr.io/acme/indexer:2.4", vcpus = 4, memory_mb = 8192, schedule = "0 2 * * *" }
    export-reports = { image = "ghcr.io/acme/reports:1.9", vcpus = 2, memory_mb = 4096, schedule = "30 3 * * 1-5", retries = 3 }
    prune-uploads  = { image = "ghcr.io/acme/janitor:0.7", vcpus = 1, memory_mb = 1024, schedule = "0 */6 * * *" }
  }

  validation {
    condition     = alltrue([for job in values(var.jobs) : length(split(" ", job.schedule)) == 5])
    error_message = "Every schedule must be a five-field cron expression."
  }
}

resource "terraform_data" "compute_environment" {
  input = {
    name      = "${var.queue_name}-compute"
    max_vcpus = var.max_vcpus
  }
}

resource "terraform_data" "queue" {
  input = {
    name        = var.queue_name
    environment = terraform_data.compute_environment.output.name
  }
}

resource "terraform_data" "job_definition" {
  for_each = var.jobs

  input = {
    name      = each.key
    image     = each.value.image
    vcpus     = each.value.vcpus
    memory_mb = each.value.memory_mb
    retries   = each.value.retries
  }
}

resource "terraform_data" "schedule" {
  for_each = var.jobs

  input = {
    job      = terraform_data.job_definition[each.key].output.name
    queue    = terraform_data.queue.output.name
    schedule = each.value.schedule
  }
}

output "schedules" {
  description = "When each job runs."
  value       = { for name, schedule in terraform_data.schedule : name => schedule.output.schedule }
}

output "peak_vcpus" {
  description = "vCPUs needed if every job ran at once."
  value       = sum([for job in values(var.jobs) : job.vcpus])
}
