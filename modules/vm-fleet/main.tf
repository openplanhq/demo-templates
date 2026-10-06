terraform {
  required_version = ">= 1.9"

  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~> 2.3"
    }
  }
}

variable "instance_count" {
  description = "How many machines to run."
  type        = number
  default     = 3

  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 12
    error_message = "instance_count must be between 1 and 12."
  }
}

variable "instance_type" {
  description = "Size of every machine."
  type        = string
  default     = "general.medium"
}

variable "image" {
  description = "Operating system image."
  type        = string
  default     = "ubuntu-24.04"

  validation {
    condition     = contains(["ubuntu-24.04", "debian-12", "rocky-9"], var.image)
    error_message = "image must be ubuntu-24.04, debian-12 or rocky-9."
  }
}

variable "packages" {
  description = "Packages cloud-init installs on first boot."
  type        = list(string)
  default     = ["curl", "htop", "jq"]
}

resource "random_pet" "hostname" {
  count = var.instance_count

  length = 2
}

data "cloudinit_config" "user_data" {
  count = var.instance_count

  gzip          = false
  base64_encode = false

  part {
    content_type = "text/cloud-config"
    content = yamlencode({
      hostname       = random_pet.hostname[count.index].id
      package_update = true
      packages       = var.packages
      write_files    = [{ path = "/etc/motd", content = "${random_pet.hostname[count.index].id} - managed by openplan\n" }]
    })
  }
}

resource "terraform_data" "instance" {
  count = var.instance_count

  input = {
    hostname       = random_pet.hostname[count.index].id
    instance_type  = var.instance_type
    image          = var.image
    user_data_hash = sha256(data.cloudinit_config.user_data[count.index].rendered)
  }
}

output "hostnames" {
  description = "Every machine's hostname."
  value       = random_pet.hostname[*].id
}
