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
