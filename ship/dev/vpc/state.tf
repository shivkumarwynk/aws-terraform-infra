terraform {
  backend "s3" {
    bucket       = "shipturtle-migartion"
    key          = "shipturtle/dev/vpc/terraform.tfstate"
    region       = "ap-south-1"
  }
}
