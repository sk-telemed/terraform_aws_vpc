/*
  A virtual private cloud (VPC) is a virtual network dedicated to AWS account. It is logically isolated from other
  virtual networks in the AWS cloud. Amazon EC2 instances can be securelty launched within VPC and will be isolated from
  the rest of AWS cloud. VPC can be fine-tudned, it is possible tp select its IP address range, create subnets,
  and configure route tables, network gateways, security settings, etc.
*/


locals {
  vpc_name = lower(var.app_name)
  tags = {
    Env = lower(var.env_name)
  }
}

resource "aws_vpc" "private_vpc" {
  cidr_block = var.vpc_cidr
  instance_tenancy = "default"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = local.vpc_name
    Env = lower(var.env_name)
  }
}
/*
  An Internet gateway is a horizontally scaled, redundant, and highly available VPC component that allows communication
  between instances in VPC and the Internet. It therefore imposes no availability risks or bandwidth constraints on
  network traffic. An Internet gateway serves two purposes: to provide a target in VPC route tables for
  Internet-routable traffic, and to perform network address translation (NAT) for instances that have been assigned
  public IP addresses.
  Internet gateway is free to use.
*/
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.private_vpc.id
  tags = merge(
  local.tags,
  {
    Name = lower(format("%s-internet-gateway", local.vpc_name))
  },
  var.tags
  )
}

/*
  NAT gateway is used to enable instances in a private subnet to connect to the Internet or other AWS services,
  but prevent the Internet from initiating a connection with those instances. Public subnets in different availability
  zone has different NAT gateways (each availability zone is completely isolated).
  NAT gateway is paid feathure and cost some money (see: https://aws.amazon.com/vpc/pricing/)
*/
resource "aws_nat_gateway" "nat_gateway" {
  count = var.have_private_subnet==true? length(var.aws_availability_zones):0
  allocation_id = aws_eip.vpc_elastic_public_ip.*.id[count.index]
  subnet_id = aws_subnet.public_subnet.*.id[count.index]
  depends_on = [
    aws_internet_gateway.internet_gateway]
  tags = {
    Name = lower(format("nat-gw-zone-%s", var.aws_availability_zones[count.index]))
    Env = lower(var.env_name)
  }
}

/*
  A subnet is a range of IP addresses in VPC, where AWS resources can be securely launched. Public subnet is used for
  resources that must be connected to the Internet. Each availability zone, has its own public subnet which is
  completly isoated from each other
*/
resource "aws_subnet" "public_subnet" {
  vpc_id = aws_vpc.private_vpc.id
  count = length(var.aws_availability_zones)
  cidr_block = cidrsubnet(aws_vpc.private_vpc.cidr_block, 8, count.index)
  availability_zone = var.aws_availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(
  local.tags,
  {
    Name = format("public-subnet-zone-%s", var.aws_availability_zones[count.index])
  },
  var.tags
  )
}

/*
  A subnet is a range of IP addresses in VPC, where AWS resources can be securely launched. Private subnet is uded for
  resources that won't be connected to the Internet. Each availability zone, has its own private subnet which is
  completly isoated from each other
*/
resource "aws_subnet" "private_subnet" {
  vpc_id = aws_vpc.private_vpc.id
  count = var.have_private_subnet==true?  length(var.aws_availability_zones):0
  cidr_block = cidrsubnet(aws_vpc.private_vpc.cidr_block, 8, count.index + length(var.aws_availability_zones))
  availability_zone = var.aws_availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = merge(
  local.tags,
  {
    Name = format("private-subnet-zone-%s", var.aws_availability_zones[count.index])
  },
  var.tags
  )
}

/*
  An Elastic IP address is a static IP address designed for dynamic cloud computing. An Elastic IP address is a
  public IP address, which is reachable from the Internet.
  Each NAT gateway in VPC shoul have pre-allocated elastic IP
*/
resource "aws_eip" "vpc_elastic_public_ip" {
  vpc = true
  count = var.have_private_subnet==true? length(var.aws_availability_zones):0
  tags = {
    Name = lower(format("eip-zone-%s", var.aws_availability_zones[count.index]))
    Env = lower(var.env_name)
  }
}

resource "aws_route_table" "private_route_table" {
  count = var.have_private_subnet==true? length(aws_subnet.private_subnet.*.id):0
  vpc_id = aws_vpc.private_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.*.id[count.index]
  }

  tags = merge(
  local.tags,
  {
    Name = lower(format("private-rt-zone-%s-%d", var.app_name, count.index))
  },
  var.tags
  )
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.private_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }

  tags = merge(
  local.tags,
  {
    Name = lower(format("public-rt-zone-%s", var.app_name))
  },
  var.tags
  )
}

resource "aws_route_table_association" "public_route_table_association" {
  count = length(aws_subnet.public_subnet.*.id)
  subnet_id = aws_subnet.public_subnet.*.id[count.index]
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "private_route_table_association" {
  count = var.have_private_subnet==true? length(aws_subnet.private_subnet.*.id):0
  subnet_id = aws_subnet.private_subnet.*.id[count.index]
  route_table_id = aws_route_table.private_route_table.*.id[count.index]
}

resource "aws_flow_log" "vpc_traffic_flow_logs" {

  log_destination = aws_cloudwatch_log_group.vpc_log_group.arn
  iam_role_arn = aws_iam_role.vpc_log_role.arn
  vpc_id = aws_vpc.private_vpc.id
  traffic_type = "ALL"
}

resource "aws_cloudwatch_log_group" "vpc_log_group" {
  name = lower(format("%s-vpc-logging-group", local.vpc_name))
}

resource "aws_iam_role" "vpc_log_role" {
  name = lower(format("%s-vpc-log-role", local.vpc_name))

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "vpc-flow-logs.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}
