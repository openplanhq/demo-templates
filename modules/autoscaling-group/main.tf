terraform {
  required_version = ">= 1.9"
}

variable "name" {
  description = "Name of the group."
  type        = string
}

variable "capacity" {
  description = "Minimum, desired and maximum instance counts."
  type = object({
    min     = number
    desired = number
    max     = number
  })
  default = {
    min     = 2
    desired = 3
    max     = 6
  }

  validation {
    condition     = var.capacity.min <= var.capacity.desired && var.capacity.desired <= var.capacity.max
    error_message = "capacity must satisfy min <= desired <= max."
  }
}

variable "target_cpu_percent" {
  description = "Average CPU the group scales to hold."
  type        = number
  default     = 60

  validation {
    condition     = var.target_cpu_percent >= 10 && var.target_cpu_percent <= 90
    error_message = "target_cpu_percent must be between 10 and 90."
  }
}

variable "instance_type" {
  description = "Size of every instance."
  type        = string
  default     = "general.large"
}

resource "terraform_data" "launch_template" {
  input = {
    name          = "${var.name}-lt"
    instance_type = var.instance_type
  }
}

resource "terraform_data" "group" {
  input = {
    name            = var.name
    launch_template = terraform_data.launch_template.output.name
    min_size        = var.capacity.min
    desired         = var.capacity.desired
    max_size        = var.capacity.max
  }
}

resource "terraform_data" "scaling_policy" {
  input = {
    group      = terraform_data.group.output.name
    metric     = "average_cpu"
    target     = var.target_cpu_percent
    cooldown_s = 300
  }
}

output "headroom" {
  description = "How many instances the group can add before it hits its maximum."
  value       = var.capacity.max - var.capacity.desired
}
