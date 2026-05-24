resource "aws_ecr_repository" "main" {
  for_each             = toset(var.repositories)
  name                 = each.value
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = each.value
  }
}

resource "aws_ecr_lifecycle_policy" "main" {
  for_each   = aws_ecr_repository.main
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images older than 3 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 3
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Expire dev images older than 3 days"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["dev"]
          countType     = "sinceImagePushed"
          countUnit     = "days"
          countNumber   = 3
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
