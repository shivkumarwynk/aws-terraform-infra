terraform {
  backend "s3" {
    bucket = "shipturtle-migration"
    key    = "shipturtle/dev/rds/terraform.tfstate"
    region = "ap-south-1"
  }
}
