terraform {
  backend "s3" {
    bucket = "shipturtle-migration"
    key    = "shipturtle/dev/alb/terraform.tfstate"
    region = "ap-south-1"
  }
}
