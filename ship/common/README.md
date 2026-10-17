# Enterprise common configuration

`config.json` is the single source for values shared by the independent
Terraform roots under `enterprise/`:

- AWS account name and region
- common tags
- VPC name, environment, CIDR, and subnet names
- security group names used by consumers
- EC2, ALB, and registry naming defaults

Each stack loads it with:

```hcl
locals {
  common = jsondecode(file("${path.module}/../common/config.json"))
}
```

The stacks remain separate Terraform states; only configuration and AWS
resource discovery are shared. Changing this file makes CI run every
deployable enterprise stack through `scripts/stack-dependencies.txt`.
