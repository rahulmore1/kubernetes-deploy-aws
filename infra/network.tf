data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "kthw" {
  cidr_block           = "10.240.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.project_name}-vpc"
    Project     = var.project_name
    Environment = "lab"
  }
}

resource "aws_internet_gateway" "kthw" {
  vpc_id = aws_vpc.kthw.id

  tags = {
    Name        = "${var.project_name}-igw"
    Project     = var.project_name
    Environment = "lab"
  }
}

resource "aws_subnet" "kthw_public" {
  vpc_id                  = aws_vpc.kthw.id
  cidr_block              = "10.240.0.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-public-subnet"
    Project     = var.project_name
    Environment = "lab"
  }
}

resource "aws_route_table" "kthw_public" {
  vpc_id = aws_vpc.kthw.id

  tags = {
    Name        = "${var.project_name}-public-rt"
    Project     = var.project_name
    Environment = "lab"
  }
}

resource "aws_route" "kthw_internet_access" {
  route_table_id         = aws_route_table.kthw_public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.kthw.id
}

resource "aws_route_table_association" "kthw_public_assoc" {
  subnet_id      = aws_subnet.kthw_public.id
  route_table_id = aws_route_table.kthw_public.id
}
