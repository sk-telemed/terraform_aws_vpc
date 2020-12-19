# Configure the AWS Provider
provider "aws" {
  region  = "us-east-1"
}
module "vpc" {
  source = "../"
  app_name = "test"
  region = "us-east-1"
  vpc_cidr = "10.10.0.0/16"
}