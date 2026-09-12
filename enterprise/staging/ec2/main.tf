provider "aws" {
  region = local.region
}

locals {
  common = jsondecode(file("${path.module}/../../common/config.json"))

  name          = "enterprise"
  region        = local.common.region
  env           = basename(dirname(abspath(path.module)))
  vpc_config    = local.common.environments[local.env].vpc
  ami           = "ami-019715e0d74f695be"
  key_name      = "wynk-staging"
  iam_role_name = "${local.name}-${local.env}-ec2"
  root_block_device = {
    encrypted = true
  }
  subnet_names = merge({
    vpn     = "lb-${local.env}-subnet-1a"
    jenkins = "app-${local.env}-subnet-1a"
    mongo   = "app-${local.env}-subnet-1b"
  }, var.subnet_names)
  security_group_names = merge({
    vpn     = "${local.vpc_config.name}-${local.env}-vpn"
    jenkins = "${local.vpc_config.name}-${local.env}-app"
    mongo   = "${local.vpc_config.name}-mongo-${local.env}-db"
  }, var.security_group_names)
  common_tags = merge(local.common.tags, { Environment = local.env })
}

module "network" {
  source = "../../../modules/v1/terraform-aws-network-lookup"

  vpc_name             = coalesce(var.vpc_name, "${local.vpc_config.name}-${local.env}")
  subnet_names         = local.subnet_names
  security_group_names = local.security_group_names
}

module "ec2_instance_profile" {
  source = "../../../modules/v1/terraform-aws-iam/modules/iam-role"

  name                    = local.iam_role_name
  create_instance_profile = true

  trust_policy_permissions = {
    EC2AssumeRole = {
      actions = ["sts:AssumeRole"]
      principals = [{
        type        = "Service"
        identifiers = ["ec2.amazonaws.com"]
      }]
    }
  }

  policies = {
    AmazonS3ReadOnlyAccess       = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = local.common_tags
}

module "ec2_instance_vpn" {
  source = "../../../modules/v1/terraform-aws-ec2-instance"

  for_each = toset(["vpn"])

  name = "${local.env}-${each.key}"

  instance_type = "t3a.medium"
  key_name      = local.key_name
  monitoring    = false
  subnet_id     = module.network.subnet_ids["vpn"]
  ami           = local.ami
  # ami = "ami-0848881f2a3dcebd1"
  iam_instance_profile   = module.ec2_instance_profile.iam_instance_profile_name
  root_block_device      = local.root_block_device
  vpc_security_group_ids = [module.network.security_group_ids["vpn"]]
  tags = merge(local.common_tags, {
    sprintoValue = "notprod"
  })
}

module "ec2_instance_jenkins" {
  source = "../../../modules/v1/terraform-aws-ec2-instance"

  for_each = toset(["jenkins"])

  name = "${local.env}-${each.key}"

  instance_type          = "t3a.small"
  key_name               = local.key_name
  monitoring             = false
  subnet_id              = module.network.subnet_ids["jenkins"]
  ami                    = local.ami
  iam_instance_profile   = module.ec2_instance_profile.iam_instance_profile_name
  root_block_device      = local.root_block_device
  vpc_security_group_ids = [module.network.security_group_ids["jenkins"]]
  tags = merge(local.common_tags, {
    sprintoValue = "notprod"
  })
}

module "ec2_instance_mongo" {
  source = "../../../modules/v1/terraform-aws-ec2-instance"

  for_each = toset(["mongo"])

  name = "${local.env}-${each.key}"

  instance_type          = "t3a.small"
  key_name               = local.key_name
  monitoring             = false
  subnet_id              = module.network.subnet_ids["mongo"]
  ami                    = local.ami
  iam_instance_profile   = module.ec2_instance_profile.iam_instance_profile_name
  root_block_device      = local.root_block_device
  vpc_security_group_ids = [module.network.security_group_ids["mongo"]]
  tags = merge(local.common_tags, {
    sprintoValue = "notprod"
  })
}
