# VPC
resource "aws_vpc" "eks_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_name}-vpc"
    Environment = var.environment
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count             = length(var.public_subnet_cidr)
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = var.public_subnet_cidr[count.index]
  availability_zone = var.availability_zones[count.index]

  map_public_ip_on_launch = true # Automatically assign a public IP address to instances

  tags = {
    Name                                            = "public-subnet-${count.index + 1}"
    Tier                                            = "public"
    "kubernetes.io/role/elb"                        = "1"
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  count             = length(var.public_subnet_cidr)
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = var.private_subnet_cidr[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name                                            = "private-subnet-${count.index + 1}"
    Tier                                            = "private"
    "kubernetes.io/role/internal-elb"               = "1"
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.eks_vpc.id

  tags = {
    Name        = "${var.project_name}-igw"
    Environment = var.environment
  }
}

#Elastic IP
resource "aws_eip" "eip-nat" {
  count  = length(var.public_subnet_cidr)
  domain = "vpc"
}

#NAT Gateway
resource "aws_nat_gateway" "nat-gw" {
  count         = length(var.public_subnet_cidr)
  allocation_id = aws_eip.eip-nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "nat-gateway-${count.index + 1}"
  }
}

#Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name        = "${var.project_name}-public-rt"
    Environment = var.environment
  }
}

resource "aws_route_table" "private" {
  count  = length(var.private_subnet_cidr)
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block     = "0.0.0.0/0" # Restrict if in Production environment
    nat_gateway_id = aws_nat_gateway.nat-gw[count.index].id
  }

  tags = {
    Name        = "${var.project_name}-private-rt"
    Environment = var.environment
  }
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidr)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(var.private_subnet_cidr)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
