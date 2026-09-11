provider "aws" {
  region = local.region
}

locals {
  common = jsondecode(file("${path.module}/../common/config.json"))

  name   = local.common.ec2.name
  region = local.common.region
  env    = local.common.ec2.environment

  subnet_names         = merge(local.common.network.ec2_subnet_names, var.subnet_names)
  security_group_names = merge(local.common.network.security_group_names, var.security_group_names)
  common_tags          = merge(local.common.tags, { Environment = local.env })
}

module "network" {
  source = "../../modules/v1/terraform-aws-network-lookup"

  vpc_name             = coalesce(var.vpc_name, local.common.network.vpc_name)
  subnet_names         = local.subnet_names
  security_group_names = local.security_group_names
}

module "ec2_instance_vpn" {
  source = "../../modules/v1/terraform-aws-ec2-instance"

  for_each = toset(["vpn"])

  name = "${local.env}-${each.key}"

  instance_type = "t3a.medium"
  key_name      = local.common.ec2.key_name
  monitoring    = false
  subnet_id     = module.network.subnet_ids["vpn"]
  ami           = local.common.ec2.ami
  # ami = "ami-0848881f2a3dcebd1"
  iam_instance_profile   = local.common.ec2.iam_instance_profile
  vpc_security_group_ids = [module.network.security_group_ids["vpn"]]
  tags = merge(local.common_tags, {
    sprintoValue = "notprod"
  })
}

module "ec2_instance_jenkins" {
  source = "../../modules/v1/terraform-aws-ec2-instance"

  for_each = toset(["jenkins"])

  name = "${local.env}-${each.key}"

  instance_type          = "t3a.small"
  key_name               = local.common.ec2.key_name
  monitoring             = false
  subnet_id              = module.network.subnet_ids["jenkins"]
  ami                    = local.common.ec2.ami
  iam_instance_profile   = local.common.ec2.iam_instance_profile
  vpc_security_group_ids = [module.network.security_group_ids["jenkins"]]
  tags = merge(local.common_tags, {
    sprintoValue = "notprod"
  })
}

module "ec2_instance_mongo" {
  source = "../../modules/v1/terraform-aws-ec2-instance"

  for_each = toset(["mongo"])

  name = "${local.env}-${each.key}"

  instance_type          = "t3a.small"
  key_name               = local.common.ec2.key_name
  monitoring             = false
  subnet_id              = module.network.subnet_ids["mongo"]
  ami                    = local.common.ec2.ami
  iam_instance_profile   = local.common.ec2.iam_instance_profile
  vpc_security_group_ids = [module.network.security_group_ids["mongo"]]
  tags = merge(local.common_tags, {
    sprintoValue = "notprod"
  })
}
