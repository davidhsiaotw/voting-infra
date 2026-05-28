variable "region" {
  description = "AWS Region to deploy to"
  type        = string
  default     = "us-east-1"
}

variable "grafana_github_client_id" {
  description = "GitHub OAuth Client ID for Grafana"
  type        = string
  sensitive   = true
}

variable "grafana_github_client_secret" {
  description = "GitHub OAuth Client Secret for Grafana"
  type        = string
  sensitive   = true
}

variable "alertmanager_smtp_host" {
  description = "SMTP host for Alertmanager emails"
  type        = string
  default     = "smtp.gmail.com:587"
}

variable "alertmanager_smtp_auth_username" {
  description = "SMTP username for Alertmanager"
  type        = string
}

variable "alertmanager_smtp_auth_password" {
  description = "SMTP password/app password for Alertmanager"
  type        = string
  sensitive   = true
}
