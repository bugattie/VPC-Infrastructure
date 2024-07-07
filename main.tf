
data "aws_region" "current" {}

# Retrieve the list of AZs in the current AWS region
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  subnet_az_map = {
    for idx in range(length(var.private_subnets)) :
    "private_subnet_${idx}" => "public_subnet_${idx}"
  }
}

# Define the VPC
resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr

  tags = {
    Name   = var.vpc_name
    Region = data.aws_region.current.name
  }
}

# Deploy the public subnets
resource "aws_subnet" "public_subnets" {
  vpc_id                  = aws_vpc.vpc.id
  for_each                = var.public_subnets
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, each.value + 100)
  availability_zone       = tolist(data.aws_availability_zones.available.names)[each.value]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.vpc_name}-${each.key}"
  }
}

# Deploy the private subnets
resource "aws_subnet" "private_subnets" {
  vpc_id            = aws_vpc.vpc.id
  for_each          = var.private_subnets
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, each.value)
  availability_zone = tolist(data.aws_availability_zones.available.names)[each.value]

  tags = {
    Name = "${var.vpc_name}-${each.key}"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.vpc_name}-igw"
  }
}

# Create EIP for NAT Gateway
resource "aws_eip" "nat_gateway_eip" {
  depends_on = [aws_internet_gateway.internet_gateway]
  for_each   = var.public_subnets
  domain     = "vpc"

  tags = {
    Name = "${var.vpc_name}-${each.key}-eip"
  }
}

# Create NAT Gateway
resource "aws_nat_gateway" "nat_gateway" {
  for_each      = var.public_subnets
  allocation_id = aws_eip.nat_gateway_eip[each.key].id
  subnet_id     = aws_subnet.public_subnets[each.key].id

  tags = {
    Name = "${var.vpc_name}-nat-gateway-${each.key}"
  }
}

# Create route tables for public subnets
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }

  tags = {
    Name = "${var.vpc_name}-public-rtb"
  }
}

# Create route tables for private subnets
resource "aws_route_table" "private_route_tables" {
  for_each = aws_subnet.private_subnets
  vpc_id   = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway[local.subnet_az_map[each.key]].id
  }

  tags = {
    Name = "${var.vpc_name}-private-rt-${each.key}"
  }
}

# Create route table associations
resource "aws_route_table_association" "public" {
  depends_on     = [aws_subnet.public_subnets]
  route_table_id = aws_route_table.public_route_table.id
  for_each       = aws_subnet.public_subnets
  subnet_id      = each.value.id
}

resource "aws_route_table_association" "private" {
  depends_on     = [aws_subnet.private_subnets]
  for_each       = var.private_subnets
  route_table_id = aws_route_table.private_route_tables[each.key].id
  subnet_id      = aws_subnet.private_subnets[each.key].id
}