# AWS network lookup

Looks up a VPC, subnets, and security groups by stable AWS names/tags. Consumer
stacks use the returned IDs instead of copying `vpc-*`, `subnet-*`, and `sg-*`
values from another Terraform working directory.

```hcl
module "network" {
  source = "../../modules/v1/terraform-aws-network-lookup"

  vpc_name = "wynk-prod"
  subnet_names = {
    app_a = "app-prod-subnet-1a"
  }
  security_group_names = {
    app = "wynk-prod-app"
  }
}
```

Each lookup must match exactly one AWS resource. Keep the `Name` tags and
security group names produced by the VPC stack unique within the account/VPC.
