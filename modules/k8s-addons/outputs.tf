output "frontend_lb_hostname" {
  value = kubernetes_service.frontend_ssl["prod"].status[0].load_balancer[0].ingress[0].hostname
}

output "grafana_lb_hostname" {
  value = data.kubernetes_service.grafana.status[0].load_balancer[0].ingress[0].hostname
}
