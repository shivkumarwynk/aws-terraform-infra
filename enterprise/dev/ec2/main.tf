provider "aws" {
  region = local.region
}

locals {
  common = jsondecode(file("${path.module}/../../common/config.json"))

  name             = "enterprise"
  region           = local.common.region
  env              = basename(dirname(abspath(path.module)))
  vpc_config       = local.common.environments[local.env].vpc
  ami              = "ami-019715e0d74f695be"
  key_name         = "wynk-staging"
  instance_profile = "wynk-staging"
  subnet_names = merge({
    vpn = "lb-${local.name}-${local.env}-snet-1a"
    app = "app-${local.name}-${local.env}-snet-1a"
    db   = "app-${local.name}-${local.env}-snet-1b"
  }, var.subnet_names)
  
  security_group_names = merge({
    vpn = "${local.vpc_config.name}-${local.env}-vpn"
    app = "${local.vpc_config.name}-${local.env}-app"
    db   = "${local.vpc_config.name}-${local.env}-db"
  }, var.security_group_names)
  common_tags = merge(local.common.tags, { Environment = local.env })
}

data "aws_security_group" "vpn" {
  name = local.security_group_names["vpn"]
}

data "aws_security_group" "app" {
  name = local.security_group_names["app"]
}

data "aws_subnet_names" "db" {
  name = local.security_group_names["db"]
}

data "aws_subnet" "vpn" {
  filter {
    name   = "tag:Name"
    values = [local.subnet_names["vpn"]]
  }
}

data "aws_subnet" "app" {
  filter {
    name   = "tag:Name"
    values = [local.subnet_names["app"]]
  }
}

data "aws_subnet" "db" {
  filter {
    name   = "tag:Name"
    values = [local.subnet_names["db"]]
  }
}


module "ec2_instance_vpn" {
  source = "../../../modules/v1/terraform-aws-ec2-instance"

  for_each = toset(["vpn"])

  name = "${local.env}-${each.key}"

  instance_type = "t3a.medium"
  key_name      = local.key_name
  monitoring    = false
  subnet_id     =  data.aws_subnet.vpn.id
  ami           = local.ami
  iam_instance_profile   = local.instance_profile
  vpc_security_group_ids = [data.aws_security_group.vpn.id]
  tags = merge(local.common_tags, {
    tier = "vpn"
  })
}



module "ec2_instance_mongo" {
  source = "../../../modules/v1/terraform-aws-ec2-instance"

  for_each = toset(["mongo"])

  name = "${local.env}-${each.key}"

  instance_type          = "t3a.small"
  key_name               = local.key_name
  monitoring             = false
  subnet_id              = data.aws_subnet.db.id
  ami                    = local.ami
  iam_instance_profile   = local.instance_profile
  vpc_security_group_ids = [data.aws_security_group.app.id]
  tags = merge(local.common_tags, {
    tier = "db"
  })
}
