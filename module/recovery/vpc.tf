# VPC in DR region
resource "aws_vpc" "dr" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    var.common_tags,
    {
      Name    = "${var.environment}-dr-vpc"
      Purpose = "DisasterRecovery"
      Region  = var.region
    }
  )
}

# Internet Gateway
resource "aws_internet_gateway" "dr" {
  vpc_id = aws_vpc.dr.id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-dr-igw"
    }
  )
}

locals {
  azs = { for idx, az in var.availability_zones : idx => az }
}
# Public Subnets (one per AZ)
resource "aws_subnet" "public" {
  for_each = local.azs

  vpc_id                  = aws_vpc.dr.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, each.key)
  availability_zone       = each.value
  map_public_ip_on_launch = true

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-dr-public-${each.value}"
      Type = "Public"
    }
  )
}

# Private Subnets (one per AZ)
resource "aws_subnet" "private" {
  for_each = local.azs

  vpc_id            = aws_vpc.dr.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, each.key + 10)
  availability_zone = each.value

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-dr-private-${each.value}"
      Type = "Private"
    }
  )
}

# Route Table for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.dr.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dr.id
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-dr-public-rt"
    }
  )
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# NAT Gateway (optional, for cost control)
resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? 1 : 0
  domain = "vpc"

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-dr-nat-eip"
    }
  )
}

resource "aws_nat_gateway" "dr" {
  count = var.enable_nat_gateway ? 1 : 0

  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-dr-nat-gateway"
    }
  )
}

# Route Table for Private Subnets
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.dr.id

  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.dr[0].id
    }
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-dr-private-rt"
    }
  )
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

