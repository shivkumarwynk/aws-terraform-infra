provider "aws" {
  region = local.region
}
data "aws_availability_zones" "available" {}

locals {
  common = jsondecode(file("${path.module}/../common/config.json"))

  name     = local.common.network.name
  region   = local.common.region
  env      = local.common.network.environment
  vpc_cidr = local.common.network.vpc_cidr
  azs      = slice(data.aws_availability_zones.available.names, 0, local.common.network.availability_zone_count)

  tags = merge(local.common.tags, {
    Name        = "${local.name}-${local.env}"
    environment = local.env
  })
  network_acls = {
    default_inbound = [
      {
        rule_number = 900
        rule_action = "allow"
        from_port   = 1024
        to_port     = 65535
        protocol    = "tcp"
        cidr_block  = "0.0.0.0/0"
      },
    ]
    default_outbound = [
      {
        rule_number = 900
        rule_action = "allow"
        from_port   = 32768
        to_port     = 65535
        protocol    = "tcp"
        cidr_block  = "0.0.0.0/0"
      },
    ]
   }
}

################################################################################
# VPC Module
################################################################################

module "vpc" {
  source = "../../modules/v1/aws-vpc"

  name = "${local.name}-${local.env}"
  cidr = local.vpc_cidr

  azs              = local.azs
  private_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets   = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 32)]
  database_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 34)]
  #intra_subnets       = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 36)]

  private_subnet_names  = local.common.network.subnet_names.private
  public_subnet_names   = local.common.network.subnet_names.public
  database_subnet_names = local.common.network.subnet_names.database
  #intra_subnet_names       = ["int-${local.env}-subnet-1a", "int-non-${local.env}-subnet-1b"]

  create_database_subnet_group = false
  manage_default_network_acl   = false
  public_dedicated_network_acl = true
  private_dedicated_network_acl = true
  private_inbound_acl_rules  = local.network_acls["default_inbound"]
  private_outbound_acl_rules = local.network_acls["default_outbound"]
  public_inbound_acl_rules = [
    {
      "cidr_block" : "0.0.0.0/0",
      "from_port" : 80,
      "protocol" : "tcp",
      "rule_action" : "allow",
      "rule_number" : 100,
      "to_port" : 80
    },
    {
      "cidr_block" : "0.0.0.0/0",
      "from_port" : 443,
      "protocol" : "tcp",
      "rule_action" : "allow",
      "rule_number" : 101,
      "to_port" : 443
    },
    {
      "cidr_block" : "0.0.0.0/0",
      "from_port" : 1024,
      "protocol" : "-1",
      "rule_action" : "allow",
      "rule_number" : 98,
      "to_port" : 65535
    }

  ]
  public_outbound_acl_rules = [
    {
      "cidr_block" : "0.0.0.0/0",
      "from_port" : 0,
      "protocol" : "-1",
      "rule_action" : "allow",
      "rule_number" : 100,
      "to_port" : 0
    }
  ]
  manage_default_route_table    = false
  manage_default_security_group = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_nat_gateway = true
  single_nat_gateway = true

  enable_vpn_gateway = false

  enable_dhcp_options              = true
  dhcp_options_domain_name         = "ap-south-1.compute.internal"
  dhcp_options_domain_name_servers = ["AmazonProvidedDNS"]

  tags = local.tags
}

################################################################################
# VPC Endpoints Module
################################################################################

module "vpc_endpoints" {
  source = "../../modules/v1/aws-vpc/modules/vpc-endpoints"

  vpc_id = module.vpc.vpc_id

  create_security_group      = true
  security_group_name_prefix = "${local.name}-${local.env}-vpc-endpoints-sg"
  security_group_description = "VPC endpoint security group"
  security_group_rules = {
    ingress_https = {
      description = "HTTPS from VPC"
      cidr_blocks = [module.vpc.vpc_cidr_block]
    }
  }

  endpoints = {
    s3 = {
      service             = "s3"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      dns_options = {
        private_dns_only_for_inbound_resolver_endpoint = false
      }
      tags = { Name = "s3-vpc-endpoint-${local.env}" }
    },
    dynamodb = {
      service         = "dynamodb"
      service_type    = "Gateway"
      route_table_ids = flatten([module.vpc.intra_route_table_ids, module.vpc.private_route_table_ids, module.vpc.public_route_table_ids])
      policy          = data.aws_iam_policy_document.dynamodb_endpoint_policy.json
      tags            = { Name = "dynamodb-vpc-endpoint-${local.env}" }
    },
    ecs = {
      service             = "ecs"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      subnet_configurations = [
        for v in module.vpc.private_subnet_objects :
        {
          ipv4      = cidrhost(v.cidr_block, 10)
          subnet_id = v.id
        }
      ]
      tags = { Name = "ecs-vpc-endpoint-${local.env}" }
    },
    ecs_telemetry = {
      create              = true
      service             = "ecs-telemetry"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      tags                = { Name = "ecs-telemetry-vpc-endpoint-${local.env}" }
    },
    ecr_api = {
      service             = "ecr.api"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      tags                = { Name = "ecr-api-vpc-endpoint-${local.env}" }
    },
    ecr_dkr = {
      service             = "ecr.dkr"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      #policy              = data.aws_iam_policy_document.generic_endpoint_policy.json
      tags = { Name = "ecr-dkr-vpc-endpoint-${local.env}" }
    },
    rds = {
      service             = "rds"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      security_group_ids  = [aws_security_group.rds.id]
      tags                = { Name = "rds-endpoint-${local.env}" }
    },
  }

  tags = merge(local.tags, {
    Endpoint = "true"
  })
}

module "vpc_endpoints_nocreate" {
  source = "../../modules/v1/aws-vpc/modules/vpc-endpoints"

  create = false
}

################################################################################
# Supporting Resources
################################################################################

data "aws_iam_policy_document" "dynamodb_endpoint_policy" {
  statement {
    effect    = "Deny"
    actions   = ["dynamodb:*"]
    resources = ["*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "aws:sourceVpc"

      values = [module.vpc.vpc_id]
    }
  }
}

data "aws_iam_policy_document" "generic_endpoint_policy" {
  statement {
    effect    = "Deny"
    actions   = ["*"]
    resources = ["*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "aws:SourceVpc"

      values = [module.vpc.vpc_id]
    }
  }
}



resource "aws_security_group" "rds" {
  name        = "${local.name}-${local.env}-db"
  description = "Allow MySQL inbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "MySQL from VPC"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
  tags = merge(
    {
      "Name" = "${local.name}-${local.env}-rds"
    },
    local.tags,
  )
}
#############
resource "aws_security_group" "db" {
  name        = "${local.name}-mongo-${local.env}-db"
  description = "Allow mongodb inbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "mongo from VPC"
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
  ingress {
    description = "redis from VPC"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
  ingress {
    description = "ssh from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
  # Allow all outbound traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(
    {
      "Name" = "${local.name}-mongo-${local.env}-db"
    },
    local.tags,
  )
}
#########SG#########
##################
resource "aws_security_group" "alb" {
  name        = "${local.name}-alb-${local.env}"
  description = "Allow alb inbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "alb from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "alb from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Allow all outbound traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(
    {
      "Name" = "${local.name}-alb-${local.env}"
    },
    local.tags,
  )
}

######
#############


#############
resource "aws_security_group" "app" {
  name        = "${local.name}-${local.env}-app"
  description = "Allow prod app inbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "app from VPC"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
  ingress {
    description = "app from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
  ingress {
    description = "efs from VPC"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
  ingress {
    description = "Allow all intbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
  ingress {
    description = "ssh from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
  # Allow all outbound traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(
    {
      "Name" = "${local.name}-${local.env}-app"
    },
    local.tags,
  )
}


resource "aws_security_group" "vpn" {
  name        = "${local.name}-${local.env}-vpn"
  description = "Allow prod vpn inbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "app from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
  ingress {
    description = "app from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
  ingress {
    description = "app from VPC"
    from_port   = 16907
    to_port     = 16907
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Allow all outbound traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(
    {
      "Name" = "${local.name}-${local.env}-vpn"
    },
    local.tags,
  )
}
