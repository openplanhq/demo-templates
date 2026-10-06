terraform {
  required_version = ">= 1.9"
}

variable "title" {
  description = "Dashboard title."
  type        = string
  default     = "Service overview"
}

variable "panels" {
  description = "Panels in reading order: a title, a query and how to draw it."
  type = list(object({
    title         = string
    query         = string
    visualization = optional(string, "timeseries")
    unit          = optional(string, "short")
  }))
  default = [
    { title = "Requests per second", query = "sum(rate(http_requests_total[5m]))", unit = "reqps" },
    { title = "Error ratio", query = "sum(rate(http_requests_total{code=~\"5..\"}[5m])) / sum(rate(http_requests_total[5m]))", unit = "percentunit" },
    { title = "p95 latency", query = "histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))", unit = "s" },
    { title = "Pods ready", query = "sum(kube_pod_status_ready{condition=\"true\"})", visualization = "stat" },
  ]

  validation {
    condition     = alltrue([for panel in var.panels : contains(["timeseries", "stat", "gauge", "table"], panel.visualization)])
    error_message = "visualization must be timeseries, stat, gauge or table."
  }
}

variable "time_range" {
  description = "How far back the dashboard looks by default."
  type        = string
  default     = "6h"
}

variable "refresh" {
  description = "How often the dashboard refreshes."
  type        = string
  default     = "30s"
}

locals {
  dashboard = jsonencode({
    title   = var.title
    time    = { from = "now-${var.time_range}", to = "now" }
    refresh = var.refresh
    panels = [
      for index, panel in var.panels : {
        id          = index + 1
        title       = panel.title
        type        = panel.visualization
        gridPos     = { w = 12, h = 8, x = (index % 2) * 12, y = floor(index / 2) * 8 }
        fieldConfig = { defaults = { unit = panel.unit } }
        targets     = [{ expr = panel.query, refId = "A" }]
      }
    ]
  })
}

resource "terraform_data" "dashboard" {
  input = {
    title   = var.title
    uid     = substr(sha1(var.title), 0, 12)
    version = substr(sha256(local.dashboard), 0, 8)
  }
}

output "url" {
  description = "Where the dashboard is viewed."
  value       = "https://grafana.demo.example/d/${terraform_data.dashboard.output.uid}"
}

output "dashboard_json" {
  description = "The rendered dashboard model."
  value       = local.dashboard
}
