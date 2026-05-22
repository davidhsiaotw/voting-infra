data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

data "aws_ssm_parameter" "db_password" {
  name            = "voting-db-password"
  with_decryption = true
}

module "vpc" {
  source = "./modules/vpc"
}

module "ecr" {
  source = "./modules/ecr"
}

module "eks" {
  source       = "./modules/eks"
  subnet_ids   = module.vpc.public_subnet_ids
  lab_role_arn = data.aws_iam_role.lab_role.arn
}

module "rds" {
  source      = "./modules/rds"
  vpc_id      = module.vpc.vpc_id
  subnet_ids  = module.vpc.public_subnet_ids
  vpc_cidr    = module.vpc.vpc_cidr_block
  db_password = data.aws_ssm_parameter.db_password.value
}
