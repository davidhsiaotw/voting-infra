resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  namespace  = "kube-system"

  set {
    name  = "provider"
    value = "aws"
  }

  set {
    name  = "domainFilters[0]"
    value = "wyxiao.games"
  }

  set {
    name  = "policy"
    value = "sync" # Allows external-dns to delete records it previously created
  }

  set {
    name  = "registry"
    value = "txt"
  }

  set {
    name  = "txtOwnerId"
    value = module.eks.cluster_name
  }

  depends_on = [module.eks]
}