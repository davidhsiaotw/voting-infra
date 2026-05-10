/*
output "frontend_lb_hostnames" {
  value = { for k, v in kubernetes_service.frontend_ssl : k => v.status[0].load_balancer[0].ingress[0].hostname }
}
*/

output "grafana_lb_hostname" {
  value = data.kubernetes_service.grafana.status[0].load_balancer[0].ingress[0].hostname
}
