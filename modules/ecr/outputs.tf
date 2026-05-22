output "repository_urls" {
  description = "The URLs of the created ECR repositories"
  value       = { for repo in aws_ecr_repository.main : repo.name => repo.repository_url }
}
