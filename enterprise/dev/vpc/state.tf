terraform {
  backend "s3" {
    bucket       = "visa2fly-db-migartion"
    key          = "enterprise/dev/vpc/terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
  }
}
