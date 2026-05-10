variable "rds_address" {
  description = "RDS instance address"
  type        = string
}

variable "db_password" {
  description = "RDS database password"
  type        = string
  sensitive   = true
}

variable "grafana_github_client_id" {
  description = "GitHub OAuth Client ID for Grafana"
  type        = string
  default     = ""
}

variable "grafana_github_client_secret" {
  description = "GitHub OAuth Client Secret for Grafana"
  type        = string
  default     = ""
  sensitive   = true
}

variable "grafana_root_url" {
  description = "Root URL for Grafana (e.g., https://grafana.wyxiao.games)"
  type        = string
  default     = ""
}

variable "alertmanager_email" {
  description = "Recipient email address for Alertmanager"
  type        = string
  default     = ""
}
