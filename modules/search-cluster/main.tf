terraform {
  required_version = ">= 1.9"
}

variable "domain_name" {
  description = "Name of the search domain."
  type        = string
  default     = "catalog-search"
}

variable "data_nodes" {
  description = "Data node count and the storage each one has."
  type = object({
    count      = number
    storage_gb = number
  })
  default = {
    count      = 3
    storage_gb = 100
  }
}

variable "dedicated_masters" {
  description = "Run three dedicated master nodes."
  type        = bool
  default     = true
}

variable "index_templates" {
  description = "Index name patterns and their shard layout."
  type = map(object({
    shards   = number
    replicas = number
  }))
  default = {
    "products-*" = { shards = 3, replicas = 1 }
    "logs-*"     = { shards = 6, replicas = 0 }
  }
}

resource "terraform_data" "master" {
  count = var.dedicated_masters ? 3 : 0

  input = {
    name = "${var.domain_name}-master-${count.index + 1}"
  }
}

resource "terraform_data" "data_node" {
  count = var.data_nodes.count

  input = {
    name       = "${var.domain_name}-data-${count.index + 1}"
    storage_gb = var.data_nodes.storage_gb
  }

  depends_on = [terraform_data.master]
}

resource "terraform_data" "index_template" {
  for_each = var.index_templates

  input = {
    pattern  = each.key
    shards   = each.value.shards
    replicas = each.value.replicas
  }

  depends_on = [terraform_data.data_node]
}

output "endpoint" {
  description = "The cluster's HTTPS endpoint."
  value       = "https://${var.domain_name}.search.demo.internal"
}

output "total_storage_gb" {
  description = "Storage across every data node."
  value       = var.data_nodes.count * var.data_nodes.storage_gb
}
