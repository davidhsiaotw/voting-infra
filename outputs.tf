output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Endpoint for EKS cluster"
  value       = module.eks.cluster_endpoint
}

output "rds_endpoint" {
  description = "Endpoint for RDS instance"
  value       = module.rds.db_endpoint
}

# output "ecr_repository_urls" {
#   description = "The URLs of the created ECR repositories"
#   value       = module.ecr.repository_urls
# }
