terraform {
  backend "s3" {
    bucket = "shipturtle-migration"
    key    = "shipturtle/dev/ecr/terraform.tfstate"
    region = "ap-south-1"
  }
}
