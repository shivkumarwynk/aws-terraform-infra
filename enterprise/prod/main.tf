locals {
  common           = jsondecode(file("${path.module}/../common/config.json"))
  environment_name = "prod"
  environment      = local.common.environments[local.environment_name]

  config = {
    network = merge(local.common.defaults.network, local.environment.network)
    ec2     = merge(local.common.defaults.ec2, local.environment.ec2)
    alb     = merge(local.common.defaults.alb, local.environment.alb)
    ecr     = merge(local.common.defaults.ecr, local.environment.ecr)
  }
}

provider "aws" {
  region = local.common.region
}

module "environment" {
  source = "../../modules/v1/terraform-aws-enterprise-environment"

  account_name = local.common.account_name
  environment  = local.environment_name
  region       = local.common.region
  config       = local.config
  tags         = local.common.tags
}
