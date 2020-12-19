output "id" {
  value = aws_vpc.private_vpc.id
}
output "vpc_name_alias" {
  value = aws_vpc.private_vpc.tags.Name
}
output "public_subnet_ids" {
  value = aws_subnet.public_subnet.*.id
}
output "private_subnet_ids" {
  value = aws_subnet.private_subnet.*.id
}
output "public_subnet_cidr_block_list" {
  value = aws_subnet.public_subnet.*.cidr_block
}
output "private_subnet_cidr_block_list" {
  value = aws_subnet.private_subnet.*.cidr_block
}
output "internet_gateway_id" {
  value = aws_internet_gateway.internet_gateway.id
}