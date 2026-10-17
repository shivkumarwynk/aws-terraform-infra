provider "aws" {
  region = local.region
}

data "aws_caller_identity" "current" {}

locals {
  common        = jsondecode(file("${path.module}/../../common/config.json"))
  region        = local.common.region
  service_files = fileset("${path.module}/../svc/svc", "*.json")
  services = {
    for file in local.service_files :
    trimsuffix(basename(file), ".json") => jsondecode(file("${path.module}/../svc/svc/${file}"))
  }

  service_secrets = {
    for name, task in local.services : name => {
      environment = one([
        for tag in task.tags : tag.value
        if tag.key == "Environment"
      ])
      workload = trimsuffix(name, "-${one([
        for tag in task.tags : tag.value
        if tag.key == "Environment"
      ])}")
      keys = distinct(flatten([
        for container in task.containerDefinitions : [
          for secret in try(container.secrets, []) : secret.name
        ]
      ]))
    }
  }

  tags = merge(local.common.tags, {
    Environment = "dev"
  })
}

resource "aws_secretsmanager_secret" "service" {
  for_each = local.service_secrets

  name                    = "${each.value.environment}/${each.value.workload}/env"
  description             = "Runtime configuration for ${each.key}"
  recovery_window_in_days = 7

  tags = merge(local.tags, {
    Name       = "${each.value.environment}/${each.value.workload}/env"
    Service    = each.key
    AWSAccount = data.aws_caller_identity.current.account_id
    SecretKeys = join(",", each.value.keys)
  })
}
