resource "kubernetes_namespace" "dev" {
  metadata {
    name = "dev"
  }
  depends_on = [module.eks]
}

resource "kubernetes_namespace" "uat" {
  metadata {
    name = "uat"
  }
  depends_on = [module.eks]
}

resource "kubernetes_namespace" "prod" {
  metadata {
    name = "prod"
  }
  depends_on = [module.eks]
}

# Extract the hostname by removing the port from the RDS endpoint
locals {
  db_endpoint_hostname = split(":", module.rds.db_endpoint)[0]
}

resource "kubernetes_secret" "db_credentials_dev" {
  metadata {
    name      = "db-credentials"
    namespace = kubernetes_namespace.dev.metadata[0].name
  }

  data = {
    DB_ENDPOINT = local.db_endpoint_hostname
    DB_PASSWORD = data.aws_ssm_parameter.db_password.value
  }

  type = "Opaque"
}

resource "kubernetes_secret" "db_credentials_uat" {
  metadata {
    name      = "db-credentials"
    namespace = kubernetes_namespace.uat.metadata[0].name
  }

  data = {
    DB_ENDPOINT = local.db_endpoint_hostname
    DB_PASSWORD = data.aws_ssm_parameter.db_password.value
  }

  type = "Opaque"
}

resource "kubernetes_secret" "db_credentials_prod" {
  metadata {
    name      = "db-credentials"
    namespace = kubernetes_namespace.prod.metadata[0].name
  }

  data = {
    DB_ENDPOINT = local.db_endpoint_hostname
    DB_PASSWORD = data.aws_ssm_parameter.db_password.value
  }

  type = "Opaque"
}
