locals {
  environments = ["dev", "qa", "uat", "prod"]
}

resource "kubernetes_namespace" "envs" {
  for_each = toset(local.environments)
  metadata {
    name = each.key
  }
}

resource "kubernetes_service" "db_service" {
  for_each = kubernetes_namespace.envs
  metadata {
    name      = "db"
    namespace = each.value.metadata[0].name
    annotations = {
      "argocd.argoproj.io/compare-options" = "IgnoreExtraneous"
    }
  }

  spec {
    type          = "ExternalName"
    external_name = var.rds_address
  }
}

resource "kubernetes_service" "frontend_ssl" {
  for_each = kubernetes_namespace.envs
  metadata {
    name      = "frontend"
    namespace = each.value.metadata[0].name
    annotations = {
      "argocd.argoproj.io/compare-options"                   = "IgnoreExtraneous"
      "service.beta.kubernetes.io/aws-load-balancer-ssl-cert" = var.ssl_certificate_arn
      "service.beta.kubernetes.io/aws-load-balancer-ssl-ports" = "443"
      "service.beta.kubernetes.io/aws-load-balancer-backend-protocol" = "http"
    }
  }

  spec {
    type = "LoadBalancer"
    port {
      name        = "http"
      port        = 80
      target_port = 80
    }
    port {
      name        = "https"
      port        = 443
      target_port = 80
    }
    selector = {
      app = "frontend"
    }
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
        additionalDataSources = [
          {
            name      = "Loki"
            type      = "loki"
            url       = "http://loki:3100"
            access    = "proxy"
            isDefault = false
          }
        ]
        sidecar = {
          dashboards = {
            enabled          = true
            label            = "grafana_dashboard"
            searchNamespace  = "ALL"
          }
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
      prometheusOperator = {
        additionalPrometheusRulesMap = {
          resource-alerts = {
            groups = [
              {
                name = "node-resources"
                rules = [
                  {
                    alert = "HighCpuUsage"
                    expr  = "100 - (avg by (instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100) > 80"
                    for   = "5m"
                    labels = { severity = "critical" }
                    annotations = { summary = "High CPU usage on {{ $labels.instance }}" }
                  },
                  {
                    alert = "HighMemoryUsage"
                    expr  = "(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 80"
                    for   = "5m"
                    labels = { severity = "critical" }
                    annotations = { summary = "High Memory usage on {{ $labels.instance }}" }
                  },
                  {
                    alert = "HighDiskUsage"
                    expr  = "(node_filesystem_size_bytes{mountpoint=\"/\"} - node_filesystem_free_bytes{mountpoint=\"/\"}) / node_filesystem_size_bytes{mountpoint=\"/\"} * 100 > 80"
                    for   = "5m"
                    labels = { severity = "critical" }
                    annotations = { summary = "High Disk usage on {{ $labels.instance }}" }
                  }
                ]
              }
            ]
          }
        }
      }
      alertmanager = {
        config = {
          global = {
            # SMTP settings (User should provide real SMTP server details)
            smtp_smarthost = "smtp.gmail.com:587"
            smtp_from      = "alerts@wyxiao.games"
            smtp_auth_username = "alerts@wyxiao.games"
            smtp_auth_password = "REPLACE_WITH_APP_PASSWORD"
          }
          route = {
            group_by = ["alertname"]
            group_wait = "30s"
            group_interval = "5m"
            repeat_interval = "12h"
            receiver = "email-notifications"
          }
          receivers = [
            {
              name = "email-notifications"
              email_configs = [
                {
                  to = var.alertmanager_email
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

data "kubernetes_service" "grafana" {
  metadata {
    name      = "${helm_release.prometheus_stack.name}-grafana"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }
  depends_on = [helm_release.prometheus_stack]
}
