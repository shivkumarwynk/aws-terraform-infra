terraform {
  backend "s3" {
    bucket       = "shipturtle-migration"
    key          = "shipturtle/dev/ecs/terraform.tfstate"
    region       = "ap-south-1"
  }
}
