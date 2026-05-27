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
    vpc_id       = module.vpc.vpc_id
  }

  depends_on = [
    helm_release.argocd,
    helm_release.argo_rollouts,
    kubernetes_namespace.dev,
    kubernetes_namespace.uat,
    kubernetes_namespace.prod,
    time_sleep.wait_for_alb_cleanup,
    aws_acm_certificate.wildcard
  ]

  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      aws eks update-kubeconfig --region ${self.triggers.region} --name ${self.triggers.cluster_name} || true

      # 1. Remove finalizers from ArgoCD resources first so it stops self-healing/recreating resources
      kubectl get applications.argoproj.io -A -o name 2>/dev/null | xargs -I {} kubectl patch {} -p '{"metadata":{"finalizers":null}}' --type=merge || true
      kubectl get appprojects.argoproj.io -A -o name 2>/dev/null | xargs -I {} kubectl patch {} -p '{"metadata":{"finalizers":null}}' --type=merge || true

      # 2. Force delete all application resources in specific namespaces to prevent stuck termination
      for ns in dev uat prod; do
        # Remove finalizers from ingresses so the AWS Load Balancer Controller doesn't get stuck
        # Patching the finalizers here ensures Terraform can delete it successfully without hanging.
        kubectl get ingress -n $ns -o name 2>/dev/null | xargs -I {} kubectl patch {} -n $ns -p '{"metadata":{"finalizers":null}}' --type=merge || true

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

      # 3. Find and delete the AWS Load Balancer to free up the ACM certificate
      # We look for ALBs created by the AWS Load Balancer Controller for our group
      echo "Searching for ALBs to clean up..."
      ALB_ARNS=$(aws elbv2 describe-load-balancers --region ${self.triggers.region} --query "LoadBalancers[?contains(LoadBalancerName, 'k8s-votingappgroup')].LoadBalancerArn" --output text)
      if [ -n "$ALB_ARNS" ] && [ "$ALB_ARNS" != "None" ]; then
        for arn in $ALB_ARNS; do
          echo "Deleting ALB: $arn"
          aws elbv2 delete-load-balancer --region ${self.triggers.region} --load-balancer-arn $arn || true
        done
        echo "Waiting for ALBs to be deleted..."
        # Wait up to 2 minutes for disassociation
        for i in {1..24}; do
          REMAINING=$(aws elbv2 describe-load-balancers --region ${self.triggers.region} --load-balancer-arns $ALB_ARNS --query "LoadBalancers" --output text 2>/dev/null || echo "")
          if [ -z "$REMAINING" ]; then
            echo "ALBs deleted successfully."
            break
          fi
          sleep 5
        done
      fi

      # 4. Cleanup VPC dependencies that block destruction (ENIs and orphaned Security Groups)
      echo "Cleaning up leaked ENIs in VPC ${self.triggers.vpc_id}..."
      ENI_IDS=$(aws ec2 describe-network-interfaces --region ${self.triggers.region} --filters Name=vpc-id,Values=${self.triggers.vpc_id} --query "NetworkInterfaces[].NetworkInterfaceId" --output text)
      if [ -n "$ENI_IDS" ] && [ "$ENI_IDS" != "None" ]; then
        for eni in $ENI_IDS; do
          echo "Deleting ENI: $eni"
          aws ec2 delete-network-interface --region ${self.triggers.region} --network-interface-id $eni || true
        done
      fi

      echo "Cleaning up orphaned Security Groups in VPC ${self.triggers.vpc_id}..."
      # skip the default SG as it can't be deleted
      SG_IDS=$(aws ec2 describe-security-groups --region ${self.triggers.region} --filters Name=vpc-id,Values=${self.triggers.vpc_id} --query "SecurityGroups[?GroupName!='default'].GroupId" --output text)
      if [ -n "$SG_IDS" ] && [ "$SG_IDS" != "None" ]; then
        for sg in $SG_IDS; do
          echo "Attempting to delete SG: $sg"
          aws ec2 delete-security-group --region ${self.triggers.region} --group-id $sg || true
        done
      fi
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
