resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
  depends_on = [module.eks]
}

resource "kubernetes_secret" "grafana_github_oauth" {
  metadata {
    name      = "grafana-github-oauth"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  data = {
    client-id     = var.grafana_github_client_id
    client-secret = var.grafana_github_client_secret
  }

  type = "Opaque"
}

resource "helm_release" "kube_prometheus_stack" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "56.6.0"
  timeout    = 900

  values = [
    <<-EOT
    kubeControllerManager:
      enabled: false

    kubeScheduler:
      enabled: false

    # Add custom alerting rules for CPU and Memory
    additionalPrometheusRulesMap:
      resource-usage:
        groups:
          - name: host-resource-usage
            rules:
              - alert: HighCpuUsage
                expr: 100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 0
                for: 1m
                labels:
                  severity: critical
                annotations:
                  summary: "High CPU usage on {{ $labels.instance }}"
                  description: "CPU usage is above 0% (current value: {{ $value }}%)"
              - alert: HighMemoryUsage
                expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 0
                for: 1m
                labels:
                  severity: critical
                annotations:
                  summary: "High Memory usage on {{ $labels.instance }}"
                  description: "Memory usage is above 0% (current value: {{ $value }}%)"

    alertmanager:
      enabled: true
      config:
        global:
          smtp_smarthost: '${var.alertmanager_smtp_host}'
          smtp_from: '${var.alertmanager_smtp_auth_username}'
          smtp_auth_username: '${var.alertmanager_smtp_auth_username}'
          smtp_auth_password: '${var.alertmanager_smtp_auth_password}'
          smtp_require_tls: true
        route:
          group_by: ['alertname']
          group_wait: 30s
          group_interval: 5m
          repeat_interval: 1h
          receiver: 'email-notifications'
        receivers:
          - name: 'email-notifications'
            email_configs:
            - to: 'whsiao5@dons.usfca.edu'
              send_resolved: true
          - name: 'null'

    grafana:
      # Inject secrets as environment variables
      envValueFrom:
        GF_AUTH_GITHUB_CLIENT_ID:
          secretKeyRef:
            name: ${kubernetes_secret.grafana_github_oauth.metadata[0].name}
            key: client-id
        GF_AUTH_GITHUB_CLIENT_SECRET:
          secretKeyRef:
            name: ${kubernetes_secret.grafana_github_oauth.metadata[0].name}
            key: client-secret

      grafana.ini:
        server:
          root_url: https://grafana.wyxiao.games
        users:
          auto_assign_org_role: Admin
        auth.github:
          enabled: true
          allow_sign_up: true
          # Use variable expansion to satisfy the 'assertNoLeakedSecrets' check
          client_id: $__env{GF_AUTH_GITHUB_CLIENT_ID}
          client_secret: $__env{GF_AUTH_GITHUB_CLIENT_SECRET}
          scopes: user:email,read:org
          auth_url: https://github.com/login/oauth/authorize
          token_url: https://github.com/login/oauth/access_token
          api_url: https://api.github.com/user
        auth:
          disable_login_form: true

      ingress:
        enabled: true
        ingressClassName: alb
        annotations:
          alb.ingress.kubernetes.io/scheme: internet-facing
          alb.ingress.kubernetes.io/target-type: ip
          alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
          alb.ingress.kubernetes.io/ssl-redirect: '443'
          alb.ingress.kubernetes.io/group.name: voting-app-group
          # ALB Controller will auto-discover the certificate based on the host name
        hosts:
          - grafana.wyxiao.games
        paths:
          - /

    nodeExporter:
      enabled: true

    prometheus:
      prometheusSpec:
        # Retention and storage can be tuned here
        retention: 1d
    EOT
  ]

  depends_on = [
    kubernetes_namespace.monitoring,
    helm_release.aws_load_balancer_controller
  ]
}
