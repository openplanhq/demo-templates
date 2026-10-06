terraform {
  required_version = ">= 1.9"
}

variable "service" {
  description = "The service the rules watch."
  type        = string
}

variable "rules" {
  description = "Alerting rules."
  type = list(object({
    alert    = string
    expr     = string
    for      = optional(string, "5m")
    severity = string
    summary  = string
  }))
  default = [
    { alert = "HighErrorRate", expr = "job:http_errors:ratio5m > 0.05", severity = "page", summary = "More than 5% of requests are failing." },
    { alert = "LatencyDegraded", expr = "job:http_latency_p95:5m > 0.5", for = "15m", severity = "ticket", summary = "p95 latency has been over 500ms for 15 minutes." },
    { alert = "PodCrashLooping", expr = "increase(kube_pod_container_status_restarts_total[15m]) > 3", severity = "ticket", summary = "A pod restarted more than three times in 15 minutes." },
  ]

  validation {
    condition     = alltrue([for rule in var.rules : contains(["page", "ticket", "info"], rule.severity)])
    error_message = "severity must be page, ticket or info."
  }

  validation {
    condition     = alltrue([for rule in var.rules : can(regex("^[0-9]+[smh]$", rule.for))])
    error_message = "for must be a duration such as 30s, 5m or 1h."
  }
}

variable "runbook_base_url" {
  description = "Runbooks live at <base>/<alert name>."
  type        = string
  default     = "https://runbooks.demo.example"
}

locals {
  rule_group = yamlencode({
    groups = [{
      name = var.service
      rules = [
        for rule in var.rules : {
          alert  = rule.alert
          expr   = rule.expr
          for    = rule.for
          labels = { severity = rule.severity, service = var.service }
          annotations = {
            summary     = rule.summary
            runbook_url = "${var.runbook_base_url}/${rule.alert}"
          }
        }
      ]
    }]
  })
}

resource "terraform_data" "rule_group" {
  input = {
    namespace = "alerts"
    name      = var.service
    checksum  = sha256(local.rule_group)
  }
}

output "rules_yaml" {
  description = "The rule group, as Prometheus loads it."
  value       = local.rule_group
}

output "paging_alerts" {
  description = "Alerts that wake someone up."
  value       = [for rule in var.rules : rule.alert if rule.severity == "page"]
}
