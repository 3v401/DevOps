# 1 VPC:

resource "aws_vpc" "my_main_vpc" {
  cidr_block           = "10.0.0.0/16" # Should I change it for other cidr_block?
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "vpc_developer"
  }
}

# 4 SUBNETS:

# Public subnet 1:
resource "aws_subnet" "my_public_subnet_1" {
  vpc_id                  = aws_vpc.my_main_vpc.id
  # For BASTION host
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "eu-north-1a"
  tags = {
    Name = "my_public_subnet_1_eu-north-1a"
  }
}

resource "aws_route_table_association" "my_public_subnet_1_rt_assoc" {
  subnet_id      = aws_subnet.my_public_subnet_1.id
  route_table_id = aws_route_table.my_public_route_table.id
}

# Public subnet 2:
resource "aws_subnet" "my_public_subnet_2" {
  vpc_id                  = aws_vpc.my_main_vpc.id
  # For API ec2 instance
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "eu-north-1b"
  tags = {
    Name = "my_public_subnet_2_eu-north-1b"
  }
}

resource "aws_route_table_association" "my_public_subnet_2_rt_assoc" {
  subnet_id      = aws_subnet.my_public_subnet_2.id
  route_table_id = aws_route_table.my_public_route_table.id
}

# Private subnet 1
resource "aws_subnet" "my_private_subnet_1" {
  vpc_id                  = aws_vpc.my_main_vpc.id
  # For Jenkins + Scanner (OWASP)
  cidr_block              = "10.0.3.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "eu-north-1a"
  tags = {
    Name = "my_private_subnet_1_eu-north-1a"
  }
}

resource "aws_route_table_association" "my_private_subnet_1_rt_assoc" {
  subnet_id      = aws_subnet.my_private_subnet_1.id
  route_table_id = aws_route_table.my_private_route_table.id
}

# Private subnet 2
resource "aws_subnet" "my_private_subnet_2" {
  vpc_id                  = aws_vpc.my_main_vpc.id
  # For monitoring
  cidr_block              = "10.0.4.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "eu-north-1b"
  tags = {
    Name = "my_private_subnet_2_eu-north-1b"
  }
}

resource "aws_route_table_association" "my_private_subnet_2_rt_assoc" {
  subnet_id      = aws_subnet.my_private_subnet_2.id
  route_table_id = aws_route_table.my_private_route_table.id
}

# 1 INTERNET GATEWAY:

resource "aws_internet_gateway" "my_main_igw" {
  vpc_id = aws_vpc.my_main_vpc.id

  tags = {
    Name = "my_main_igw"
  }
}

# 2 ROUTE TABLES:

# Public route table:

resource "aws_route_table" "my_public_route_table" {
  vpc_id = aws_vpc.my_main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_main_igw.id
  }

  tags = {
    Name = "my_public_route_table"
  }
}

# Private route table:

resource "aws_route_table" "my_private_route_table" {
  vpc_id = aws_vpc.my_main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.my_NAT_gateway.id
  }

  tags = {
    Name = "my_private_route_table"
  }
}

# NAT Gateway:
# (Allow private subnets to reach the internet)

resource "aws_nat_gateway" "my_NAT_gateway" {
  allocation_id = aws_eip.example.id
  # NAT Gateways must always be created in a public subnet.
  # NAT Gateway needs public internet access to relay outbound traffic from private subnets.
  # It uses the Internet Gateway, so it must be in a subnet that’s publicly routed.
  subnet_id     = aws_subnet.my_public_subnet_1.id

  tags = {
    Name = "my_NAT_gw"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.my_main_igw]
}


# NAT EIP:
# Elastic IP (EIP) gives the NAT Gateway a static public IP so it can reach the internet.
resource "aws_eip" "my_main_nat_eip" {
  tags = {
    Name = "my_main_nat_eip"
  }
}