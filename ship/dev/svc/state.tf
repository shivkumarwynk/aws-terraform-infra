terraform {
  backend "s3" {
    bucket = "shipturtle-migration"
    key    = "shipturtle/dev/svc/terraform.tfstate"
    region = "ap-south-1"
  }
}
