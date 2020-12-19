variable "app_name" {
}

variable "vpc_cidr" {
  description = "CIDR of the VPC. Dont limit it to much. Prefer to use: \"Private IPv4 address spaces\""
}

variable "aws_availability_zones" {
  description = "Set of availability zones within region to spin up instances in. There is no need to specify more than 2 right now"
  default = [
    "us-east-1a",
    "us-east-1b"
  ]
}

variable "region" {
  default = "us-east-1"
}

variable "env_name" {
  default = "base"
}

variable "have_private_subnet" {
  default = true
}
variable "tags" {
  type = map(string)
  default = {}
}
variable "private_subnet_tags" {
  default = {}
}