resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true

  depends_on = [module.eks]
}

resource "helm_release" "argo_rollouts" {
  name             = "argo-rollouts"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-rollouts"
  namespace        = "argo-rollouts"
  create_namespace = true

  depends_on = [module.eks]
}

resource "null_resource" "argocd_cleanup" {
  triggers = {
    cluster_name = module.eks.cluster_name
    region       = var.region
  }

  depends_on = [
    helm_release.argocd,
    helm_release.argo_rollouts,
    kubernetes_namespace.dev,
    kubernetes_namespace.uat,
    kubernetes_namespace.prod,
    time_sleep.wait_for_alb_cleanup
  ]

  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      aws eks update-kubeconfig --region ${self.triggers.region} --name ${self.triggers.cluster_name} || true

      # 1. Remove finalizers from ArgoCD resources first so it stops self-healing/recreating resources
      kubectl get applications.argoproj.io -A -o name 2>/dev/null | xargs -I {} kubectl patch {} -p '{"metadata":{"finalizers":null}}' --type=merge || true
      kubectl get appprojects.argoproj.io -A -o name 2>/dev/null | xargs -I {} kubectl patch {} -p '{"metadata":{"finalizers":null}}' --type=merge || true

      # 2. Delete all ingresses to ensure AWS Load Balancers are cleaned up by the AWS controller
      kubectl delete ingress --all --all-namespaces || true

      # 3. Force delete all pods in application namespaces to prevent stuck termination
      for ns in dev uat prod; do
        kubectl delete deployments --all -n $ns --force --grace-period=0 || true
        kubectl delete statefulsets --all -n $ns --force --grace-period=0 || true
        kubectl delete rollouts --all -n $ns --force --grace-period=0 || true
        kubectl delete replicasets --all -n $ns --force --grace-period=0 || true

        kubectl get pvc -n $ns -o name 2>/dev/null | xargs -I {} kubectl patch {} -n $ns -p '{"metadata":{"finalizers":null}}' --type=merge || true
        kubectl delete pvc --all -n $ns --force --grace-period=0 || true

        kubectl get pods -n $ns -o name 2>/dev/null | xargs -I {} kubectl patch {} -n $ns -p '{"metadata":{"finalizers":null}}' --type=merge || true
        echo "forcing to delete $ns pods..."
        kubectl delete pods --all -n $ns --force --grace-period=0 || true
      done
    EOT
  }
}

resource "time_sleep" "wait_for_alb_cleanup" {
  depends_on = [module.eks]
  create_duration = "0s"
  destroy_duration = "3m"
}

resource "helm_release" "argocd_apps" {
  name       = "argocd-apps"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  namespace  = "argocd"

  depends_on = [
    helm_release.argocd,
    kubernetes_namespace.dev,
    kubernetes_namespace.uat,
    kubernetes_namespace.prod,
    null_resource.argocd_cleanup
  ]

  values = [
    <<-EOT
    applications:
      dev:
        namespace: argocd
        project: default
        source:
          repoURL: https://github.com/davidhsiaotw/voting-infra.git
          targetRevision: HEAD
          path: k8s-manifests/dev
        destination:
          server: https://kubernetes.default.svc
          namespace: dev
        syncPolicy:
          automated:
            prune: true
            selfHeal: true
      uat:
        namespace: argocd
        project: default
        source:
          repoURL: https://github.com/davidhsiaotw/voting-infra.git
          targetRevision: HEAD
          path: k8s-manifests/uat
        destination:
          server: https://kubernetes.default.svc
          namespace: uat
        syncPolicy:
          automated:
            prune: true
            selfHeal: true
      prod:
        namespace: argocd
        project: default
        source:
          repoURL: https://github.com/davidhsiaotw/voting-infra.git
          targetRevision: HEAD
          path: k8s-manifests/prod
        destination:
          server: https://kubernetes.default.svc
          namespace: prod
        syncPolicy:
          automated:
            prune: true
            selfHeal: true
    EOT
  ]
}
