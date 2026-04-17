resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  tags = { Name = var.vpc_name }
}

resource "aws_subnet" "this" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.vpc_cidr
  map_public_ip_on_launch = var.is_public # Tự cấp IP Public nếu là VPC Public
  tags = { Name = "${var.vpc_name}-Subnet" }
}

# Chỉ tạo Internet Gateway nếu is_public là true
resource "aws_internet_gateway" "this" {
  count  = var.is_public ? 1 : 0
  vpc_id = aws_vpc.this.id
  tags = { Name = "${var.vpc_name}-IGW" }
}

resource "aws_route_table" "this" {
  vpc_id = aws_vpc.this.id
  tags = { Name = "${var.vpc_name}-RT" }
}

# Chỉ tạo Route ra Internet nếu is_public là true
resource "aws_route" "internet_access" {
  count                  = var.is_public ? 1 : 0
  route_table_id         = aws_route_table.this.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id
}

resource "aws_route_table_association" "this" {
  subnet_id      = aws_subnet.this.id
  route_table_id = aws_route_table.this.id
}