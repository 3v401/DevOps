# Security Group          Purpose
# sg_API:                 Public API: HTTP, HTTPS + SSH
# sg_JENKINS:             Jenkins & Internal tools from Bation
# sg_SCANNER:             Monitorin/Scanner, port 8080 + Bastion SSH
# sg_BASTION:             SSH access for Bastion from my IP
# sg_BUILDER:             SSH to Builder from Bastion and Jenkins


# 4 SG:

# 1st SG -------------------------------------------------------------------------------BASTION

resource "aws_security_group" "sg_BASTION" {
  name        = "sg_BASTION"
  description = "Allow SSH from your IP only (BASTION)"
  vpc_id      = aws_vpc.my_main_vpc.id

  tags = {
    Name = "sg_BASTION"
  }
}

resource "aws_vpc_security_group_ingress_rule" "sg_BASTION_ipv4" {
  security_group_id = aws_security_group.sg_BASTION.id
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
  # generate_ip.tfvars.sh Gets your IP
  # my_ip.auto.tfvars Loads your IP as a variable
  # variables.tf Declares my_ip variable
  cidr_ipv4         = var.my_ip
}

resource "aws_vpc_security_group_egress_rule" "sg_BASTION_all_outbound_traffic_ipv4" {
  security_group_id = aws_security_group.sg_BASTION.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# 2nd SG for -------------------------------------------------------------------------------API

resource "aws_security_group" "sg_API" {
  name        = "sg_API"
  description = "Allow connections to the API"
  vpc_id      = aws_vpc.my_main_vpc.id

  tags = {
    Name = "sg_API"
  }
}

resource "aws_vpc_security_group_ingress_rule" "sg_API_ipv4_HTTPS" {
  security_group_id = aws_security_group.sg_API.id
  cidr_ipv4         = "0.0.0.0/0" # If only from VPC: aws_vpc.my_main_vpc.cidr_block
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
  tags = {
    Name = "Allow HTTPS inbound connection to API ipv4"
  }
}

resource "aws_vpc_security_group_ingress_rule" "sg_API_ipv4_HTTP" {
  security_group_id = aws_security_group.sg_API.id
  cidr_ipv4         = "0.0.0.0/0" # If only from VPC: aws_vpc.my_main_vpc.cidr_block
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
  tags = {
    Name = "Allow HTTP inbound connection to API ipv4"
  }
}

resource "aws_vpc_security_group_egress_rule" "sg_API_all_outbound_traffic_ipv4" {
  security_group_id = aws_security_group.sg_API.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
  tags = {
    Name = "Allow all outbound connection to API ipv4"
  }
}

resource "aws_vpc_security_group_ingress_rule" "sg_API_ssh_from_bastion" {
  security_group_id            = aws_security_group.sg_API.id
  referenced_security_group_id = aws_security_group.sg_BASTION.id
  from_port                    = 22
  ip_protocol                  = "tcp"
  to_port                      = 22

  tags = {
    Name = "Allow SSH from Bastion"
  }
}

resource "aws_vpc_security_group_ingress_rule" "sg_API_ssh_from_jenkins" {
  security_group_id            = aws_security_group.sg_API.id
  referenced_security_group_id = aws_security_group.sg_JENKINS.id
  from_port                    = 22
  ip_protocol                  = "tcp"
  to_port                      = 22

  tags = {
    Name = "Allow SSH from Jenkins"
  }
}

# 3rd SG -------------------------------------------------------------------------------JENKINS
# Required inline in this SG for "security_groups"

resource "aws_security_group" "sg_JENKINS" {
  name   = "sg_JENKINS"
  description = "SG for Jenkins"
  vpc_id = aws_vpc.my_main_vpc.id

  # SSH SG connection to Jenkins:

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_BASTION.id]
  }

  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    security_groups = [aws_security_group.sg_BASTION.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg_JENKINS"
  }
}

# 4th SG -------------------------------------------------------------------------------SCANNER

resource "aws_security_group" "sg_SCANNER" {
  name        = "sg_SCANNER"
  description = "SCANNER sg"
  vpc_id      = aws_vpc.my_main_vpc.id

  tags = {
    Name = "sg_SCANNER"
  }
}

resource "aws_vpc_security_group_ingress_rule" "sg_SCANNER_ipv4" {
  security_group_id = aws_security_group.sg_SCANNER.id
  cidr_ipv4 = "10.0.0.0/16"
  from_port         = 8080
  ip_protocol       = "tcp"
  to_port           = 8080

  tags = {
    Name = "Allow any device in the 10.0.0.0/16 VPC CIDR block to access port 8080"
  }
}

resource "aws_vpc_security_group_egress_rule" "sg_SCANNER_all_outbound_traffic_ipv4" {
  security_group_id = aws_security_group.sg_SCANNER.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_vpc_security_group_ingress_rule" "sg_SCANNER_ssh_from_bastion" {
  security_group_id            = aws_security_group.sg_SCANNER.id
  referenced_security_group_id = aws_security_group.sg_BASTION.id
  from_port                    = 22
  ip_protocol                  = "tcp"
  to_port                      = 22
  tags = {
    Name = "Allow SSH from Bastion to scanner EC2 instance"
  }
}

resource "aws_vpc_security_group_ingress_rule" "sg_SCANNER_ssh_from_jenkins" {
  security_group_id            = aws_security_group.sg_SCANNER.id
  referenced_security_group_id = aws_security_group.sg_JENKINS.id
  from_port                    = 22
  ip_protocol                  = "tcp"
  to_port                      = 22

  tags = {
    Name = "Allow SSH from Jenkins to scanner EC2 instance"
  }
}

# 5th SG -------------------------------------------------------------------------------MONITORING

resource "aws_security_group" "sg_MONITORING" {
  name        = "sg_MONITORING"
  description = "Allow internal monitoring access"
  vpc_id      = aws_vpc.my_main_vpc.id

  tags = {
    Name = "sg_MONITORING"
  }
}

resource "aws_vpc_security_group_ingress_rule" "sg_MONITORING_ipv4" {
  security_group_id = aws_security_group.sg_MONITORING.id
  cidr_ipv4 = "10.0.0.0/16"
  from_port         = 8080
  ip_protocol       = "tcp"
  to_port           = 8080
  tags = {
    Name = "Allow any device in the 10.0.0.0/16 VPC CIDR block to access port 8080"
  }
}

resource "aws_vpc_security_group_egress_rule" "sg_MONITORING_all_outbound_traffic_ipv4" {
  security_group_id = aws_security_group.sg_MONITORING.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_vpc_security_group_ingress_rule" "sg_MONITORING_ssh_from_bastion" {
  security_group_id            = aws_security_group.sg_MONITORING.id
  referenced_security_group_id = aws_security_group.sg_BASTION.id
  from_port                    = 22
  ip_protocol                  = "tcp"
  to_port                      = 22
  tags = {
    Name = "Allow SSH from Bastion to monitoring EC2 instance"
  }
}

resource "aws_vpc_security_group_ingress_rule" "sg_MONITORING_ssh_from_jenkins" {
  security_group_id            = aws_security_group.sg_MONITORING.id
  referenced_security_group_id = aws_security_group.sg_JENKINS.id
  from_port                    = 22
  ip_protocol                  = "tcp"
  to_port                      = 22

  tags = {
    Name = "Allow SSH from Jenkins to mointoring EC2 instance"
  }
}

# 6th SG -------------------------------------------------------------------------------BUILDER

resource "aws_security_group" "sg_BUILDER" {
  name              = "sg_BUILDER"
  description       = "Allow SSH from Bastions and Jenkins to BUILDER"
  vpc_id            = aws_vpc.my_main_vpc.id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [
      aws_security_group.sg_BASTION.id,
      # Bastion ID
      aws_security_group.sg_JENKINS.id
      # Jenkins ID
    ]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg_BUILDER"
  }
}