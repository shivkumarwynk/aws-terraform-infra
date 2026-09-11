provider "aws" {
  region = local.region
}

locals {
  name   = "enterprise"
  region = "ap-south-1"
  env    = "staging"

  subnet_names = {
    vpn     = "lb-prod-subnet-1a"
    jenkins = "app-prod-subnet-1a"
    mongo   = "app-prod-subnet-1b"
  }

  security_group_names = {
    vpn     = "wynk-prod-vpn"
    jenkins = "wynk-prod-app"
    mongo   = "wynk-mongo-prod-db"
  }
}

module "network" {
  source = "../../modules/v1/terraform-aws-network-lookup"

  vpc_name             = var.vpc_name
  subnet_names         = merge(local.subnet_names, var.subnet_names)
  security_group_names = merge(local.security_group_names, var.security_group_names)
}

module "ec2_instance_vpn" {
  source = "../../modules/v1/terraform-aws-ec2-instance"

  for_each = toset(["vpn"])

  name = "staging-${each.key}"

  instance_type = "t3a.medium"
  key_name      = "wynk-staging"
  monitoring    = false
  subnet_id     = module.network.subnet_ids["vpn"]
  ami           = "ami-019715e0d74f695be"
  # ami = "ami-0848881f2a3dcebd1"
  iam_instance_profile   = "wynk-staging"
  vpc_security_group_ids = [module.network.security_group_ids["vpn"]]
  tags = {
    Terraform    = "true"
    Environment  = "staging"
    sprintoValue = "notprod"
  }
}

module "ec2_instance_jenkins" {
  source = "../../modules/v1/terraform-aws-ec2-instance"

  for_each = toset(["jenkins"])

  name = "staging-${each.key}"

  instance_type          = "t3a.small"
  key_name               = "wynk-staging"
  monitoring             = false
  subnet_id              = module.network.subnet_ids["jenkins"]
  ami                    = "ami-019715e0d74f695be"
  iam_instance_profile   = "wynk-staging"
  vpc_security_group_ids = [module.network.security_group_ids["jenkins"]]
  tags = {
    Terraform    = "true"
    Environment  = "staging"
    sprintoValue = "notprod"
  }
}

module "ec2_instance_mongo" {
  source = "../../modules/v1/terraform-aws-ec2-instance"

  for_each = toset(["mongo"])

  name = "staging-${each.key}"

  instance_type          = "t3a.small"
  key_name               = "wynk-staging"
  monitoring             = false
  subnet_id              = module.network.subnet_ids["mongo"]
  ami                    = "ami-019715e0d74f695be"
  iam_instance_profile   = "wynk-staging"
  vpc_security_group_ids = [module.network.security_group_ids["mongo"]]
  tags = {
    Terraform    = "true"
    Environment  = "staging"
    sprintoValue = "notprod"
  }
}
