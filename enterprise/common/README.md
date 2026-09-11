# Enterprise common configuration

`config.json` is the single source for values shared by the three independent
Terraform environment roots under `enterprise/`:

- AWS account name and region
- common tags
- defaults repeated across environments (AZ count, NAT, AMI, ALB and ECR)
- environment-specific VPC CIDRs, EC2 instances, ALB overrides, and ECR names

Each environment loads it and merges common defaults with its overrides:

```hcl
locals {
  common = jsondecode(file("${path.module}/../common/config.json"))
  environment = local.common.environments["prod"]

  config = {
    network = merge(local.common.defaults.network, local.environment.network)
    ec2     = merge(local.common.defaults.ec2, local.environment.ec2)
    alb     = merge(local.common.defaults.alb, local.environment.alb)
    ecr     = merge(local.common.defaults.ecr, local.environment.ecr)
  }
}
```

`enterprise/prod`, `enterprise/staging`, and `enterprise/dev` each call the
same `terraform-aws-enterprise-environment` module but use separate S3 state
keys. Changing this file makes CI run all three environments through
`scripts/stack-dependencies.txt`.
