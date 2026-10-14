terraform {
  backend "s3" {
    bucket = "visa2fly-db-migartion"
    key    = "enterprise/dev/s3/terraform.tfstate"
    region = "ap-south-1"
  }
}
