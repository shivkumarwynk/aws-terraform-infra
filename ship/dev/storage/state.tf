terraform {
  backend "s3" {
    bucket = "shipturtle-migration"
    key    = "shipturtle/dev/storage/terraform.tfstate"
    region = "ap-south-1"
  }
}
