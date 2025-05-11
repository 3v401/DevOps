# 4 SG:

# 1st SG for public-facing EC2 API:

resource "aws_security_group" "my_first_allow_tls" {
  name        = "my_first_allow_tls"
  description = "Allow HTTP/HTTPS from the internet"
  vpc_id      = aws_vpc.my_main_vpc.id

  tags = {
    Name = "my_first_allow_tls"
  }
}

resource "aws_vpc_security_group_ingress_rule" "my_first_allow_tls_ipv4_HTTPS" {
  security_group_id = aws_security_group.my_first_allow_tls.id
  cidr_ipv4         = "0.0.0.0/0" # If only from VPC: aws_vpc.my_main_vpc.cidr_block
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_ingress_rule" "my_first_allow_tls_ipv4_HTTP" {
  security_group_id = aws_security_group.my_first_allow_tls.id
  cidr_ipv4         = "0.0.0.0/0" # If only from VPC: aws_vpc.my_main_vpc.cidr_block
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "my_first_allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.my_first_allow_tls.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# 2nd SG for internal tools. Jenkins, OWASP:
# Required inline in this SG for "security_groups"

resource "aws_security_group" "my_second_allow_tls" {
  name   = "my_second_allow_tls"
  description = "Access from BASTION only"
  vpc_id = aws_vpc.my_main_vpc.id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.my_fourth_allow_tls.id]
  }

  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    security_groups = [aws_security_group.my_fourth_allow_tls.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "my_second_allow_tls"
  }
}


# 3rd SG for monitoring/scanning:

resource "aws_security_group" "my_third_allow_tls" {
  name        = "my_third_allow_tls"
  description = "Allow internal monitoring access"
  vpc_id      = aws_vpc.my_main_vpc.id

  tags = {
    Name = "my_third_allow_tls"
  }
}

resource "aws_vpc_security_group_ingress_rule" "my_third_allow_tls_ipv4" {
  security_group_id = aws_security_group.my_third_allow_tls.id
  cidr_ipv4 = "10.0.0.0/16"
  from_port         = 8080
  ip_protocol       = "tcp"
  to_port           = 8080
}

resource "aws_vpc_security_group_egress_rule" "my_third_allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.my_third_allow_tls.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# 4th SG for SSH into private resources:

resource "aws_security_group" "my_fourth_allow_tls" {
  name        = "my_fourth_allow_tls"
  description = "Allow SSH from your IP only (BASTION)"
  vpc_id      = aws_vpc.my_main_vpc.id

  tags = {
    Name = "my_fourth_allow_tls"
  }
}

resource "aws_vpc_security_group_ingress_rule" "my_fourth_allow_tls_ipv4" {
  security_group_id = aws_security_group.my_fourth_allow_tls.id
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
  # generate_ip.tfvars.sh Gets your IP
  # my_ip.auto.tfvars Loads your IP as a variable
  # variables.tf Declares my_ip variable
  cidr_ipv4         = var.my_ip
}

resource "aws_vpc_security_group_egress_rule" "my_fourth_allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.my_fourth_allow_tls.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}