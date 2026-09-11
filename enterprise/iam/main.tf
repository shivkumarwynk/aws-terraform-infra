provider "aws" {
  region = local.common.region
}

locals {
  common = jsondecode(file("${path.module}/../common/config.json"))
}

module "ec2_role" {
  source = "../../modules/v1/terraform-aws-iam/modules/iam-role"

  name                    = local.common.ec2.iam_instance_profile
  use_name_prefix         = false
  description             = "Enterprise EC2 instance role"
  create_instance_profile = true

  trust_policy_permissions = {
    ec2 = {
      actions = ["sts:AssumeRole"]
      principals = [{
        type        = "Service"
        identifiers = ["ec2.amazonaws.com"]
      }]
    }
  }

  policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = merge(local.common.tags, {
    Name        = local.common.ec2.iam_instance_profile
    Environment = local.common.ec2.environment
  })
}
