provider "aws" {
  region = local.region
}

locals {
  common = jsondecode(file("${path.module}/../../common/config.json"))

  env          = basename(dirname(abspath(path.module)))
  region       = local.common.region
  repositories = toset(["frontend", "backend", "devops"])
  tags         = merge(local.common.tags, { Environment = local.env })

  lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep the newest 20 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 20
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

module "repository" {
  source = "../../../modules/v1/terraform-aws-ecr"

  for_each = local.repositories

  repository_name                 = each.value
  repository_image_tag_mutability = "MUTABLE"
  repository_encryption_type      = "AES256"
  repository_image_scan_on_push   = false

  attach_repository_policy = false

  create_lifecycle_policy                = true
  repository_lifecycle_policy            = local.lifecycle_policy
  manage_registry_scanning_configuration = false

  create_registry_replication_configuration = false

  tags = merge(local.tags, { Name = each.value })
}
