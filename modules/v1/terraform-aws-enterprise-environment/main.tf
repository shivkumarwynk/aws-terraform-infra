data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name = "${var.account_name}-${var.environment}"
  azs  = slice(data.aws_availability_zones.available.names, 0, var.config.network.availability_zone_count)

  tags = merge(var.tags, {
    Name        = local.name
    Environment = var.environment
  })

  public_subnets   = [for index, _ in local.azs : cidrsubnet(var.config.network.vpc_cidr, 8, index + 32)]
  private_subnets  = [for index, _ in local.azs : cidrsubnet(var.config.network.vpc_cidr, 4, index)]
  database_subnets = [for index, _ in local.azs : cidrsubnet(var.config.network.vpc_cidr, 8, index + 34)]

  public_subnet_names = [
    for az in local.azs : "lb-${var.environment}-subnet-${reverse(split("-", az))[0]}"
  ]
  private_subnet_names = [
    for az in local.azs : "app-${var.environment}-subnet-${reverse(split("-", az))[0]}"
  ]
  database_subnet_names = [
    for az in local.azs : "db-${var.environment}-subnet-${reverse(split("-", az))[0]}"
  ]

  security_groups = {
    rds = {
      description = "Allow MySQL from the VPC"
      ingress_rules = {
        mysql = {
          description = "MySQL from VPC"
          from_port   = 3306
          to_port     = 3306
          ip_protocol = "tcp"
          cidr_ipv4   = var.config.network.vpc_cidr
        }
      }
    }
    database = {
      description = "Allow database and administration traffic from the VPC"
      ingress_rules = {
        mongodb = {
          description = "MongoDB from VPC"
          from_port   = 27017
          to_port     = 27017
          ip_protocol = "tcp"
          cidr_ipv4   = var.config.network.vpc_cidr
        }
        redis = {
          description = "Redis from VPC"
          from_port   = 6379
          to_port     = 6379
          ip_protocol = "tcp"
          cidr_ipv4   = var.config.network.vpc_cidr
        }
        ssh = {
          description = "SSH from VPC"
          from_port   = 22
          to_port     = 22
          ip_protocol = "tcp"
          cidr_ipv4   = var.config.network.vpc_cidr
        }
      }
    }
    app = {
      description = "Allow application traffic from the VPC"
      ingress_rules = {
        all_from_vpc = {
          description = "All traffic from VPC"
          ip_protocol = "-1"
          cidr_ipv4   = var.config.network.vpc_cidr
        }
      }
    }
    vpn = {
      description = "Allow VPN traffic"
      ingress_rules = {
        http = {
          description = "HTTP from VPC"
          from_port   = 80
          to_port     = 80
          ip_protocol = "tcp"
          cidr_ipv4   = var.config.network.vpc_cidr
        }
        https = {
          description = "HTTPS from VPC"
          from_port   = 443
          to_port     = 443
          ip_protocol = "tcp"
          cidr_ipv4   = var.config.network.vpc_cidr
        }
        vpn = {
          description = "VPN client traffic"
          from_port   = 16907
          to_port     = 16907
          ip_protocol = "tcp"
          cidr_ipv4   = "0.0.0.0/0"
        }
      }
    }
    alb_external = {
      description = "Allow public ALB traffic"
      ingress_rules = merge(
        var.config.alb.enable_http ? {
          http = {
            description = "HTTP from internet"
            from_port   = 80
            to_port     = 80
            ip_protocol = "tcp"
            cidr_ipv4   = "0.0.0.0/0"
          }
        } : {},
        var.config.alb.enable_https ? {
          https = {
            description = "HTTPS from internet"
            from_port   = 443
            to_port     = 443
            ip_protocol = "tcp"
            cidr_ipv4   = "0.0.0.0/0"
          }
        } : {}
      )
    }
    alb_internal = {
      description = "Allow internal ALB traffic from the VPC"
      ingress_rules = merge(
        var.config.alb.enable_http ? {
          http = {
            description = "HTTP from VPC"
            from_port   = 80
            to_port     = 80
            ip_protocol = "tcp"
            cidr_ipv4   = var.config.network.vpc_cidr
          }
        } : {},
        var.config.alb.enable_internal_https ? {
          https = {
            description = "HTTPS from VPC"
            from_port   = 443
            to_port     = 443
            ip_protocol = "tcp"
            cidr_ipv4   = var.config.network.vpc_cidr
          }
        } : {}
      )
    }
  }

  external_https_enabled = var.config.alb.enable_https && var.config.alb.external_certificate_arn != ""
  internal_https_enabled = var.config.alb.enable_internal_https && var.config.alb.internal_certificate_arn != ""

  external_listeners = merge(
    var.config.alb.enable_http ? {
      http = local.external_https_enabled ? {
        port     = 80
        protocol = "HTTP"
        redirect = {
          port        = "443"
          protocol    = "HTTPS"
          status_code = "HTTP_301"
        }
        } : {
        port     = 80
        protocol = "HTTP"
        forward = {
          target_group_key = "app"
        }
      }
    } : {},
    local.external_https_enabled ? {
      https = {
        port            = 443
        protocol        = "HTTPS"
        ssl_policy      = var.config.alb.ssl_policy
        certificate_arn = var.config.alb.external_certificate_arn
        forward = {
          target_group_key = "app"
        }
      }
    } : {}
  )

  internal_listeners = merge(
    var.config.alb.enable_http ? {
      http = {
        port     = 80
        protocol = "HTTP"
        forward = {
          target_group_key = "app"
        }
      }
    } : {},
    local.internal_https_enabled ? {
      https = {
        port            = 443
        protocol        = "HTTPS"
        ssl_policy      = var.config.alb.ssl_policy
        certificate_arn = var.config.alb.internal_certificate_arn
        forward = {
          target_group_key = "app"
        }
      }
    } : {}
  )
}

module "vpc" {
  source = "../aws-vpc"

  name = local.name
  cidr = var.config.network.vpc_cidr

  azs              = local.azs
  public_subnets   = local.public_subnets
  private_subnets  = local.private_subnets
  database_subnets = local.database_subnets

  public_subnet_names   = local.public_subnet_names
  private_subnet_names  = local.private_subnet_names
  database_subnet_names = local.database_subnet_names

  create_database_subnet_group = true
  enable_nat_gateway           = var.config.network.enable_nat_gateway
  single_nat_gateway           = var.config.network.single_nat_gateway
  enable_dns_hostnames         = true
  enable_dns_support           = true

  tags = local.tags
}

module "security_groups" {
  source = "../terraform-aws-security-group"

  for_each = local.security_groups

  name                   = "${local.name}-${replace(each.key, "_", "-")}"
  use_name_prefix        = false
  description            = each.value.description
  vpc_id                 = module.vpc.vpc_id
  ingress_rules          = each.value.ingress_rules
  enable_exclusive_rules = true

  egress_rules = {
    all = {
      description = "Allow all outbound traffic"
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  tags = merge(local.tags, {
    Name = "${local.name}-${replace(each.key, "_", "-")}"
  })
}

module "ec2_role" {
  source = "../terraform-aws-iam/modules/iam-role"

  name                    = "${local.name}-ec2"
  use_name_prefix         = false
  description             = "${local.name} EC2 instance role"
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

  tags = local.tags
}

module "ec2_instances" {
  source = "../terraform-aws-ec2-instance"

  for_each = var.config.ec2.instances

  name                   = "${local.name}-${each.key}"
  instance_type          = each.value.instance_type
  ami                    = try(each.value.ami, var.config.ec2.ami)
  key_name               = try(each.value.key_name, var.config.ec2.key_name)
  monitoring             = try(each.value.monitoring, var.config.ec2.monitoring)
  iam_instance_profile   = module.ec2_role.instance_profile_name
  subnet_id              = each.value.subnet_type == "public" ? module.vpc.public_subnets[each.value.subnet_index] : module.vpc.private_subnets[each.value.subnet_index]
  vpc_security_group_ids = [module.security_groups[each.value.security_group].id]

  tags = merge(local.tags, try(each.value.tags, {}))
}

module "alb_external" {
  source = "../terraform-aws-alb"

  create = var.config.alb.create_external

  name                       = "${local.name}-external"
  load_balancer_type         = "application"
  vpc_id                     = module.vpc.vpc_id
  subnets                    = module.vpc.public_subnets
  internal                   = false
  create_security_group      = false
  security_groups            = [module.security_groups["alb_external"].id]
  enable_deletion_protection = var.config.alb.enable_deletion_protection
  listeners                  = local.external_listeners

  target_groups = {
    app = {
      name_prefix      = "appex"
      protocol         = "HTTP"
      port             = var.config.alb.target_port
      target_type      = "instance"
      vpc_id           = module.vpc.vpc_id
      create_attachment = false
      health_check = {
        enabled  = true
        path     = var.config.alb.health_check_path
        protocol = "HTTP"
        matcher  = "200-399"
      }
    }
  }

  tags = local.tags
}

module "alb_internal" {
  source = "../terraform-aws-alb"

  create = var.config.alb.create_internal

  name                       = "${local.name}-internal"
  load_balancer_type         = "application"
  vpc_id                     = module.vpc.vpc_id
  subnets                    = module.vpc.private_subnets
  internal                   = true
  create_security_group      = false
  security_groups            = [module.security_groups["alb_internal"].id]
  enable_deletion_protection = var.config.alb.enable_deletion_protection
  listeners                  = local.internal_listeners

  target_groups = {
    app = {
      name_prefix      = "appin"
      protocol         = "HTTP"
      port             = var.config.alb.target_port
      target_type      = "instance"
      vpc_id           = module.vpc.vpc_id
      create_attachment = false
      health_check = {
        enabled  = true
        path     = var.config.alb.health_check_path
        protocol = "HTTP"
        matcher  = "200-399"
      }
    }
  }

  tags = local.tags
}

module "ecr" {
  source = "../terraform-aws-ecr"

  repository_name                 = var.config.ecr.repository_name
  repository_image_scan_on_push   = true
  repository_image_tag_mutability = "IMMUTABLE"

  repository_lifecycle_policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the latest images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = var.config.ecr.images_to_keep
      }
      action = {
        type = "expire"
      }
    }]
  })

  tags = local.tags
}
