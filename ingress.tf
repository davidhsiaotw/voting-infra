resource "kubernetes_ingress_v1" "voting_app_dev" {
  metadata {
    name      = "voting-app-ingress"
    namespace = kubernetes_namespace.dev.metadata[0].name
    annotations = {
      "alb.ingress.kubernetes.io/scheme"          = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"     = "ip"
      "alb.ingress.kubernetes.io/listen-ports"    = "[{\"HTTP\": 80}, {\"HTTPS\": 443}]"
      "alb.ingress.kubernetes.io/ssl-redirect"    = "443"
      "alb.ingress.kubernetes.io/certificate-arn" = aws_acm_certificate.wildcard.arn
      "alb.ingress.kubernetes.io/group.name"      = "voting-app-group"
    }
  }

  spec {
    ingress_class_name = "alb"
    rule {
      host = "dev.wyxiao.games"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "frontend"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  wait_for_load_balancer = true

  depends_on = [
    helm_release.aws_load_balancer_controller,
    aws_acm_certificate_validation.main
  ]
}

# Wait for ALB to be provisioned and assigned a hostname
resource "aws_route53_record" "dev" {
  allow_overwrite = true
  zone_id         = data.aws_route53_zone.main.zone_id
  name            = "dev.wyxiao.games"
  type            = "A"

  alias {
    name                   = kubernetes_ingress_v1.voting_app_dev.status[0].load_balancer[0].ingress[0].hostname
    zone_id                = "Z35SXDOTRQ7X7K" # ALB Hosted Zone ID for us-east-1
    evaluate_target_health = true
  }
}

# --- UAT Environment ---
resource "kubernetes_ingress_v1" "voting_app_uat" {
  metadata {
    name      = "voting-app-ingress"
    namespace = kubernetes_namespace.uat.metadata[0].name
    annotations = {
      "alb.ingress.kubernetes.io/scheme"          = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"     = "ip"
      "alb.ingress.kubernetes.io/listen-ports"    = "[{\"HTTP\": 80}, {\"HTTPS\": 443}]"
      "alb.ingress.kubernetes.io/ssl-redirect"    = "443"
      "alb.ingress.kubernetes.io/certificate-arn" = aws_acm_certificate.wildcard.arn
      "alb.ingress.kubernetes.io/group.name"      = "voting-app-group"
    }
  }

  spec {
    ingress_class_name = "alb"
    rule {
      host = "uat.wyxiao.games"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "frontend"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  wait_for_load_balancer = true

  depends_on = [
    helm_release.aws_load_balancer_controller,
    aws_acm_certificate_validation.main
  ]
}

resource "aws_route53_record" "uat" {
  allow_overwrite = true
  zone_id         = data.aws_route53_zone.main.zone_id
  name            = "uat.wyxiao.games"
  type            = "A"

  alias {
    name                   = kubernetes_ingress_v1.voting_app_uat.status[0].load_balancer[0].ingress[0].hostname
    zone_id                = "Z35SXDOTRQ7X7K" # ALB Hosted Zone ID for us-east-1
    evaluate_target_health = true
  }
}

# --- PROD Environment ---
resource "kubernetes_ingress_v1" "voting_app_prod" {
  metadata {
    name      = "voting-app-ingress"
    namespace = kubernetes_namespace.prod.metadata[0].name
    annotations = {
      "alb.ingress.kubernetes.io/scheme"          = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"     = "ip"
      "alb.ingress.kubernetes.io/listen-ports"    = "[{\"HTTP\": 80}, {\"HTTPS\": 443}]"
      "alb.ingress.kubernetes.io/ssl-redirect"    = "443"
      "alb.ingress.kubernetes.io/certificate-arn" = aws_acm_certificate.wildcard.arn
      "alb.ingress.kubernetes.io/group.name"      = "voting-app-group"
    }
  }

  spec {
    ingress_class_name = "alb"
    rule {
      host = "wyxiao.games"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "frontend"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  wait_for_load_balancer = true

  depends_on = [
    helm_release.aws_load_balancer_controller,
    aws_acm_certificate_validation.main
  ]
}

resource "aws_route53_record" "prod" {
  allow_overwrite = true
  zone_id         = data.aws_route53_zone.main.zone_id
  name            = "wyxiao.games"
  type            = "A"

  alias {
    name                   = kubernetes_ingress_v1.voting_app_prod.status[0].load_balancer[0].ingress[0].hostname
    zone_id                = "Z35SXDOTRQ7X7K" # ALB Hosted Zone ID for us-east-1
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "grafana" {
  allow_overwrite = true
  zone_id         = data.aws_route53_zone.main.zone_id
  name            = "grafana.wyxiao.games"
  type            = "A"

  alias {
    name                   = kubernetes_ingress_v1.voting_app_dev.status[0].load_balancer[0].ingress[0].hostname
    zone_id                = "Z35SXDOTRQ7X7K" # ALB Hosted Zone ID for us-east-1
    evaluate_target_health = true
  }
}
