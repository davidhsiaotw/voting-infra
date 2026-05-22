variable "repositories" {
  description = "List of ECR repository names to create"
  type        = list(string)
  default = [
    "voting-app-frontend",
    "voting-app-vote",
    "voting-app-result",
    "voting-app-worker"
  ]
}
