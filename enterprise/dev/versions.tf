terraform {
  required_version = ">= 1.10"

  backend "s3" {
    key          = "enterprise/dev/terraform.tfstate"
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
