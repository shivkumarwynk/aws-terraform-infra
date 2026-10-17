terraform {
  backend "s3" {
    bucket = "shipturtle-migration"
    key    = "shipturtle/dev/ec2/terraform.tfstate"
    region = "ap-south-1"
  }
}
