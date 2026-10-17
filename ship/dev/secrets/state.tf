terraform {
  backend "s3" {
    bucket = "shipturtle-migration"
    key    = "shipturtle/dev/secrets/terraform.tfstate"
    region = "ap-south-1"
  }
}
