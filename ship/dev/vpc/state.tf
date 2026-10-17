terraform {
  backend "s3" {
    bucket       = "shipturtle-migration"
    key          = "shipturtle/dev/vpc/terraform.tfstate"
    region       = "ap-south-1"
  }
}
