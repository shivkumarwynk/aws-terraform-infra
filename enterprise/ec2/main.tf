provider "aws" {
  region = local.region
}

locals {
  name   = "wynk"
  region = "ap-south-1"
  env    = "staging"
}

####

module "ec2_instance_vpn" {
  source  = "../../modules/v1/terraform-aws-ec2-instance"

  for_each = toset(["vpn"])

  name = "staging-${each.key}"

  instance_type = "t3a.medium"
  key_name      = "wynk-staging"
  monitoring    = false
  subnet_id     = "subnet-0dd8dd9e0a8388e88"
  ami           = "ami-019715e0d74f695be"
  #ami           = "ami-0848881f2a3dcebd1"
  iam_instance_profile = "wynk-staging"
  vpc_security_group_ids= ["sg-07ba126a4e53a30df"]
  tags = {
    Terraform   = "true"
    Environment = "staging"
    sprintoValue = "notprod"
  }
}

module "ec2_instance_jenkins" {
  source  = "../../modules/v1/terraform-aws-ec2-instance"

  for_each = toset(["jenkins"])

  name = "staging-${each.key}"

  instance_type = "t3a.small"
  key_name      = "wynk-staging"
  monitoring    = false
  subnet_id     = "subnet-0b54c30a2fed2a5bc"
  ami           = "ami-019715e0d74f695be"
  iam_instance_profile = "wynk-staging"
  vpc_security_group_ids= ["sg-0804a4d14943686a9"]
  tags = {
    Terraform   = "true"
    Environment = "staging"
    sprintoValue = "notprod"
  }
}

module "ec2_instance_mongo" {
  source  = "../../modules/v1/terraform-aws-ec2-instance"

  for_each = toset(["mongo"])

  name = "staging-${each.key}"

  instance_type = "t3a.small"
  key_name      = "wynk-staging"
  monitoring    = false
  subnet_id     = "subnet-0b54c30a2fed2a5bc"
  ami           = "ami-019715e0d74f695be"
  iam_instance_profile = "wynk-staging"
  vpc_security_group_ids= ["sg-040511d1ecf7ede1e"]
  tags = {
    Terraform   = "true"
    Environment = "staging"
    sprintoValue = "notprod"
  }
}
