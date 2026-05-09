data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = data.aws_iam_role.lab_role.arn

  vpc_config {
    subnet_ids = var.subnet_ids
  }
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "managed-nodes"
  node_role_arn   = data.aws_iam_role.lab_role.arn
  subnet_ids      = var.subnet_ids

  scaling_config {
    desired_size = 4
    max_size     = 5
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  instance_types = ["t3.medium"]
}
