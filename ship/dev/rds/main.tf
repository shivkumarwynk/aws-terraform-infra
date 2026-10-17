provider "aws" {
  region = local.region
}

locals {
  common = jsondecode(file("${path.module}/../../common/config.json"))

  env        = basename(dirname(abspath(path.module)))
  region     = local.common.region
  vpc_config = local.common.environments[local.env].vpc
  vpc_name   = "${local.vpc_config.name}-${local.env}"

  database_subnet_names = [
    "db-${local.vpc_name}-snet-1a",
    "db-${local.vpc_name}-snet-1b",
  ]

  tags = merge(local.common.tags, {
    Environment = local.env
  })
}

data "aws_vpc" "this" {
  filter {
    name   = "tag:Name"
    values = [local.vpc_name]
  }
}

data "aws_subnet" "database" {
  for_each = toset(local.database_subnet_names)

  filter {
    name   = "tag:Name"
    values = [each.value]
  }

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.this.id]
  }
}

resource "aws_db_subnet_group" "this" {
  name       = "${local.vpc_name}-database"
  subnet_ids = [for subnet in data.aws_subnet.database : subnet.id]

  tags = merge(local.tags, {
    Name = "${local.vpc_name}-database"
  })
}

resource "aws_security_group" "rds" {
  name        = "${local.vpc_name}-rds"
  description = "Access to the dev RDS databases from within the VPC"
  vpc_id      = data.aws_vpc.this.id

  ingress {
    description = "MySQL from the VPC"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.this.cidr_block]
  }

  ingress {
    description = "PostgreSQL from the VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.this.cidr_block]
  }

  tags = merge(local.tags, {
    Name = "${local.vpc_name}-rds"
  })
}

resource "aws_db_parameter_group" "mysql" {
  name        = "${local.vpc_name}-mysql-8-4"
  family      = "mysql8.4"
  description = "MySQL 8.4 parameters for ${local.vpc_name}"

  parameter {
    name  = "slow_query_log"
    value = "1"
  }

  parameter {
    name  = "long_query_time"
    value = "5"
  }

  parameter {
    name  = "log_output"
    value = "FILE"
  }

  tags = local.tags
}

resource "aws_db_parameter_group" "postgres" {
  name        = "${local.vpc_name}-postgres-15"
  family      = "postgres15"
  description = "PostgreSQL 15 parameters for ${local.vpc_name}"

  parameter {
    name  = "autovacuum"
    value = "1"
  }

  parameter {
    name  = "log_duration"
    value = "1"
  }

  tags = local.tags
}

resource "aws_db_instance" "mysql" {
  identifier = "${local.vpc_name}-mysql"

  engine         = "mysql"
  engine_version = "8.4.11"
  instance_class = "db.t4g.micro"

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name                     = "application"
  username                    = "dbadmin"
  manage_master_user_password = true
  port                        = 3306

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.mysql.name
  publicly_accessible    = false
  multi_az               = false

  enabled_cloudwatch_logs_exports = ["error", "slowquery"]
  backup_retention_period         = 7
  auto_minor_version_upgrade      = false
  apply_immediately               = true
  deletion_protection             = false
  skip_final_snapshot             = true

  tags = merge(local.tags, {
    Name = "${local.vpc_name}-mysql"
  })
}

resource "aws_db_instance" "postgres" {
  identifier = "${local.vpc_name}-postgres"

  engine         = "postgres"
  engine_version = "15.18"
  instance_class = "db.t4g.micro"

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name                     = "application"
  username                    = "dbadmin"
  manage_master_user_password = true
  port                        = 5432

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.postgres.name
  publicly_accessible    = false
  multi_az               = false

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  backup_retention_period         = 7
  auto_minor_version_upgrade      = false
  apply_immediately               = true
  deletion_protection             = false
  skip_final_snapshot             = true

  tags = merge(local.tags, {
    Name = "${local.vpc_name}-postgres"
  })
}
