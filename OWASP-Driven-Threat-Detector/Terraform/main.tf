resource "aws_vpc" "my_main_vpc" {
  cidr_block           = "10.0.0.0/16" # Should I change it for other cidr_block?
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "vpc_developer"
  }
}

resource "aws_subnet" "my_main_subnet" {
  vpc_id                  = aws_vpc.my_main_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "eu-north-1a"
  tags = {
    Name = "my_main_public_vpc_eu-north-1a"
  }
}

resource "aws_internet_gateway" "my_main_igw" {
  vpc_id = aws_vpc.my_main_vpc.id

  tags = {
    Name = "my_main_igw"
  }
}

resource "aws_route_table" "my_main_route_table" {
  vpc_id = aws_vpc.my_main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_main_igw.id
  }

  tags = {
    Name = "my_main_route_table"
  }
}

resource "aws_route_table_association" "my_main_public_rt_association" {
  subnet_id      = aws_subnet.my_main_subnet.id
  route_table_id = aws_route_table.my_main_route_table.id
}

resource "aws_security_group" "allow_tls" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.my_main_vpc.id
  tags = {
    Name = "allow_tls"
  }
}

resource "aws_vpc_security_group_ingress_rule" "my_main_allow_tls_ipv4" {
  security_group_id = aws_security_group.allow_tls.id
  cidr_ipv4         = aws_vpc.my_main_vpc.cidr_block
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "my_main_allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.allow_tls.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_key_pair" "my_main_terrakey_auth" {
  key_name   = "my_main_terrakey"
  public_key = file("~/.ssh/terrakey.pub")
}

resource "aws_instance" "my_main_EC2_instance" {
  ami           = data.aws_ami.my_main_ubuntu_EC2_data.id
  instance_type = "t3.micro"
  key_name = aws_key_pair.my_main_terrakey_auth.id
  vpc_security_group_ids = [aws_vpc_security_group_ingress_rule.my_main_allow_tls_ipv4.id]
  subnet_id = aws_subnet.my_main_subnet.id
  user_data = file("userdata1.tpl") # configuration file to bootstrap the server

  root_block_device {
    volume_size = 10
  }

  tags = {
    Name = "ubuntu-server"
  }
}