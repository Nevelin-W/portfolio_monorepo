resource "aws_vpc" "vpc_01" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    ManagedByTf = "Yes"
    Environment = upper(var.environment)
    Name        = "${upper(var.environment)}_vpc_01"

  }
}

resource "aws_subnet" "public_subnets" {
  count                   = var.public_subnet_count
  vpc_id                  = aws_vpc.vpc_01.id
  cidr_block              = cidrsubnet(var.cidr_block, 8, count.index)
  map_public_ip_on_launch = true
  availability_zone       = var.azs[count.index]

  tags = {
    ManagedByTf = "Yes"
    Environment = upper(var.environment)
    Name        = "${upper(var.environment)}_public_subnet_${format("%02d", count.index + 1)}"
  }
}

resource "aws_internet_gateway" "igw_01" {
  vpc_id = aws_vpc.vpc_01.id

  tags = {
    ManagedByTf = "Yes"
    Environment = upper(var.environment)
    Name        = "${upper(var.environment)}_igw_01"
  }
}

resource "aws_route_table" "rt_01" {
  vpc_id = aws_vpc.vpc_01.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_01.id
  }

  tags = {
    ManagedByTf = "Yes"
    Environment = upper(var.environment)
    Name        = "${upper(var.environment)}_rt_01"
  }
}

resource "aws_route_table_association" "rta" {
  count          = var.public_subnet_count
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.rt_01.id
}