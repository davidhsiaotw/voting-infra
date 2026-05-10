variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "voting-app"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "voting-cluster"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
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
  description = "Root URL for Grafana"
  type        = string
  default     = ""
}

variable "alertmanager_email" {
  description = "Recipient email address for Alertmanager"
  type        = string
  default     = ""
}
