# ----------------------------------------------------------------
# security_groups.tf
# ----------------------------------------------------------------

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

  ingress {
    # Only allow ALB to hit Jenkins on port 8080
    from_port    = 8080
    to_port      = 8080
    protocol     = "tcp"
    security_groups = [aws_security_group.sg_ALB_JENKINS.id]
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

# 7th SG ------------------------------------------------------------------------------- ALB_JENKINS SG

resource "aws_security_group" "sg_ALB_JENKINS" {
  name          = "alb_jenkins_sg"
  description   = "Allow GitHub webhook IPs to Jenkins through ALB"
  vpc_id        = aws_vpc.my_main_vpc.id

  ingress {
    description  = "GitHub Webhooks"
    from_port    = 80
    protocol     = "tcp"
    to_port      = 80
    cidr_blocks = [
      "192.30.252.0/22",
      "185.199.108.0/22",
      "140.82.112.0/20",
      "143.55.64.0/20"
    ]
  }

  ingress {
  description = "Jenkins configuration UI"
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = [var.my_ip]
}


  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ALB_JENKINS_sg"
  }
}