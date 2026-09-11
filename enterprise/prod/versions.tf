terraform {
  required_version = ">= 1.5.7"

  backend "s3" {
    key          = "enterprise/prod/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.29"
    }
  }
}
