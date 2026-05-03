resource "aws_ecr_repository" "repos" {
  for_each = toset(["frontend", "vote", "result", "worker"])
  
  name                 = "${var.project_name}-${each.key}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}
