variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the RDS instance"
  type        = list(string)
}

variable "vpc_cidr" {
  description = "The CIDR block of the VPC to allow inbound traffic from"
  type        = string
}

variable "db_password" {
  description = "The database password"
  type        = string
  sensitive   = true
}
