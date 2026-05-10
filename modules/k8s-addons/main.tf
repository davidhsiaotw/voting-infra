locals {
  environments = ["dev", "qa", "uat", "prod"]
}

resource "kubernetes_namespace" "envs" {
  for_each = toset(locals.environments)
  metadata {
    name = each.key
  }
}

resource "kubernetes_secret" "db_secret" {
  for_each = kubernetes_namespace.envs
  metadata {
    name      = "db-secret"
    namespace = each.value.metadata[0].name
  }

  data = {
    password = var.db_password
  }

  type = "Opaque"
}

resource "kubernetes_service" "db_service" {
  for_each = kubernetes_namespace.envs
  metadata {
    name      = "db"
    namespace = each.value.metadata[0].name
  }

  spec {
    type          = "ExternalName"
    external_name = var.rds_address
  }
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  version    = "5.46.7"

  set {
    name  = "server.service.type"
    value = "LoadBalancer"
  }
}

resource "helm_release" "argo_rollouts" {
  name       = "argo-rollouts"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-rollouts"
  namespace  = "kube-system"
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

resource "helm_release" "prometheus_stack" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name

  values = [
    yamlencode({
      grafana = {
        enabled = true
        "grafana.ini" = {
          server = {
            root_url = var.grafana_root_url
          }
          "auth.github" = {
            enabled       = var.grafana_github_client_id != "" ? true : false
            allow_sign_up = true
            client_id     = var.grafana_github_client_id
            client_secret = var.grafana_github_client_secret
            scopes        = "user:email,read:org"
            auth_url      = "https://github.com/login/oauth/authorize"
            token_url     = "https://github.com/login/oauth/access_token"
            api_url       = "https://api.github.com/user"
          }
          auth = {
            disable_login_form = var.grafana_github_client_id != "" ? true : false
          }
        }
        service = {
          type = "LoadBalancer"
        }
      }
      prometheus = {
        prometheusSpec = {
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                accessModes = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = "10Gi"
                  }
                }
              }
            }
          }
        }
      }
      alertmanager = {
        config = {
          global = {
            slack_api_url = var.alertmanager_slack_url
          }
          route = {
            group_by = ["alertname"]
            group_wait = "30s"
            group_interval = "5m"
            repeat_interval = "12h"
            receiver = "slack-notifications"
          }
          receivers = [
            {
              name = "slack-notifications"
              slack_configs = [
                {
                  channel = "#alerts"
                  send_resolved = true
                }
              ]
            }
          ]
        }
      }
    })
  ]
}

resource "helm_release" "loki" {
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki-stack"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name

  set {
    name  = "loki.persistence.enabled"
    value = "true"
  }
  set {
    name  = "loki.persistence.size"
    value = "10Gi"
  }
}
