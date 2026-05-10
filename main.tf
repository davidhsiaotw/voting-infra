module "vpc" {
  source = "./modules/vpc"

  project_name          = var.project_name
  cluster_name          = var.cluster_name
  vpc_cidr              = var.vpc_cidr
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  availability_zones    = var.availability_zones
}

module "eks" {
  source = "./modules/eks"

  project_name = var.project_name
  cluster_name = var.cluster_name
  subnet_ids   = module.vpc.private_subnet_ids
  vpc_id       = module.vpc.vpc_id
}

module "rds" {
  source = "./modules/rds"

  project_name       = var.project_name
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  eks_nodes_sg_id    = module.eks.cluster_security_group_id
}

module "ecr" {
  source = "./modules/ecr"
  project_name = var.project_name
}

module "dns" {
  source = "./modules/dns"
  project_name = var.project_name
}

module "k8s_addons" {
  source      = "./modules/k8s-addons"
  rds_address = module.rds.rds_address
  db_password = module.rds.db_password

  grafana_github_client_id     = var.grafana_github_client_id
  grafana_github_client_secret = var.grafana_github_client_secret
  grafana_root_url             = var.grafana_root_url
  alertmanager_email           = var.alertmanager_email

  depends_on = [module.eks, module.rds]
}
