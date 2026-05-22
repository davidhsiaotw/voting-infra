variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "voting-eks"
}

variable "subnet_ids" {
  description = "List of subnet IDs for the EKS cluster"
  type        = list(string)
}

variable "lab_role_arn" {
  description = "ARN of the AWS Academy LabRole"
  type        = string
}
