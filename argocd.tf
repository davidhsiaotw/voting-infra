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
    helm_release.argo_rollouts
  ]

  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      aws eks update-kubeconfig --region ${self.triggers.region} --name ${self.triggers.cluster_name} || true
      
      # Delete all ingresses to ensure AWS Load Balancers are cleaned up
      kubectl delete ingress --all --all-namespaces || true
      
      # Remove finalizers from ArgoCD resources
      kubectl get applications.argoproj.io -A -o name 2>/dev/null | xargs -I {} kubectl patch {} -p '{"metadata":{"finalizers":null}}' --type=merge || true
      kubectl get appprojects.argoproj.io -A -o name 2>/dev/null | xargs -I {} kubectl patch {} -p '{"metadata":{"finalizers":null}}' --type=merge || true
    EOT
  }
}