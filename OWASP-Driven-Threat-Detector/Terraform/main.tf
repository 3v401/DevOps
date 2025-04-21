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

# 5 EC2 instances + Keys:

# 1st instance: Bastion Host + Key pair
# Purpose: Secure access point to private instances (via SSH)
# Install: Only SSH

resource "aws_key_pair" "my_bastion_key_auth" {
  key_name   = "my_bastion_key"
  public_key = file(var.bastion_public_key_path)
}

resource "aws_instance" "my_bastion_EC2_instance" {
  ami           = data.aws_ami.my_main_ubuntu_EC2_data.id
  instance_type = "t3.micro"
  key_name = aws_key_pair.my_bastion_key_auth.id
  vpc_security_group_ids = [aws_security_group.my_fourth_allow_tls_ipv4.id]
  subnet_id = aws_subnet.my_public_subnet_1.id
  user_data = file("userdata_bastion.tpl") # configuration file to bootstrap the server

  root_block_device {
    volume_size = 10
  }

  tags = {
    Name = "bastion-server"
  }
}

# 2nd instance: Public API server + Key pair
# Purpose: Hosts your public-facing application (API)
# Install Nginx, backendapp and Certbot

resource "aws_key_pair" "my_api_key_auth" {
  key_name   = "my_api_key"
  public_key = file(var.api_public_key_path)
}

resource "aws_instance" "my_api_EC2_instance" {
  ami           = data.aws_ami.my_main_ubuntu_EC2_data.id
  instance_type = "t3.micro"
  key_name = aws_key_pair.my_api_key_auth.id
  vpc_security_group_ids = [aws_security_group.my_first_allow_tls.id]
  subnet_id = aws_subnet.my_public_subnet_2.id
  user_data = file("userdata_api.tpl") # configuration file to bootstrap the server

  root_block_device {
    volume_size = 10
  }

  tags = {
    Name = "api-server"
  }
}

# 3rd instance: Jenkins server + Key pair
# Purpose: Automates build, test, deploy
# Install : Jenkins, Git, Docker

resource "aws_key_pair" "my_jenkins_key_auth" {
  key_name   = "my_jenkins_key"
  public_key = file(var.jenkins_public_key_path)
}

resource "aws_instance" "my_jenkins_EC2_instance" {
  ami           = data.aws_ami.my_main_ubuntu_EC2_data.id
  instance_type = "t3.micro"
  key_name = aws_key_pair.my_jenkins_key_auth.id
  vpc_security_group_ids = [aws_security_group.my_second_allow_tls.id]
  subnet_id = aws_subnet.my_private_subnet_1.id
  user_data = file("userdata_jenkins.tpl") # configuration file to bootstrap the server
  iam_instance_profile = aws_iam_instance_profile.my_ec2_instance_profile.name

  root_block_device {
    volume_size = 10
  }

  tags = {
    Name = "jenkins-server"
  }
}

# 4th instance: OWASP Scanner + Key pair
# Purpose: Runs vulnerability scanning (DevSecOps)
# Install: OWASP Dependency-Check, ZAP or Trivy

resource "aws_key_pair" "my_scanner_key_auth" {
  key_name   = "my_scanner_key"
  public_key = file(var.scanner_public_key_path)
}

resource "aws_instance" "my_scanner_EC2_instance" {
  ami           = data.aws_ami.my_main_ubuntu_EC2_data.id
  instance_type = "t3.micro"
  key_name = aws_key_pair.my_scanner_key_auth.id
  vpc_security_group_ids = [aws_security_group.my_second_allow_tls.id]
  subnet_id = aws_subnet.my_private_subnet_1.id
  user_data = file("userdata_scanner.tpl") # configuration file to bootstrap the server
  iam_instance_profile = aws_iam_instance_profile.my_ec2_instance_profile.name

  root_block_device {
    volume_size = 10
  }

  tags = {
    Name = "scanner-server"
  }
}

# 5th instance: Monitorin + Key pair
# Purpose: Aggregates logs, metrics, alerts
# Install: Prometheus, Grafana, Loki, or ELK Stack

resource "aws_key_pair" "my_monitoring_key_auth" {
  key_name   = "my_monitoring_key"
  public_key = file(var.monitoring_public_key_path)
}

resource "aws_instance" "my_monitoring_EC2_instance" {
  ami           = data.aws_ami.my_main_ubuntu_EC2_data.id
  instance_type = "t3.micro"
  key_name = aws_key_pair.my_monitoring_key_auth.id
  vpc_security_group_ids = [aws_security_group.my_third_allow_tls.id]
  subnet_id = aws_subnet.my_private_subnet_2.id
  user_data = file("userdata_monitoring.tpl") # configuration file to bootstrap the server
  iam_instance_profile = aws_iam_instance_profile.my_ec2_instance_profile.name

  root_block_device {
    volume_size = 10
  }

  tags = {
    Name = "monitoring-server"
  }
}

# S3 bucket:
# Goal: Store logs

resource "aws_s3_bucket" "my_s3_bucket" {
  bucket = "my-s3-bucket"

  tags = {
    Name        = "My bucket"
    Environment = "Dev"
  }
}

# CloudWatch Alarm:
# Goal: Monitor if CPU usage exceeds a threshold (80%)

resource "aws_cloudwatch_metric_alarm" "my_cpu_usage" {
  alarm_name                = "my_cpu_usage"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = 2
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  period                    = 120
  statistic                 = "Average"
  threshold                 = 80
  alarm_description         = "This metric monitors ec2 cpu utilization"
  insufficient_data_actions = []
  alarm_actions = [aws_sns_topic.alarm_topic.arn]
}

# CloudWatch Log:
# Goal: Store application logs from EC2 instances

resource "aws_cloudwatch_log_group" "my_app_logs" {
  name = "/myapp/logs"
  tags = {
    Environment = "production"
    Application = "serviceA"
  }
}

# CloudWatch Metric Filter:
# Extract metrics (login attempts, error counts...)

resource "aws_cloudwatch_log_metric_filter" "my_error_counts" {
  name           = "My_Error_Count"
  pattern        = "ERROR"
  log_group_name = aws_cloudwatch_log_group.my_app_logs.name

  metric_transformation {
    name      = "EventCount"
    namespace = "MyApp/Monitoring"
    value     = "1"
  }
}

# Send Alerts to your email:
# When CPU alarm triggers an email will be received.

resource "aws_sns_topic" "my_alarm_topic" {
  name = "my_cloudwatch_alerts_topic"
}

resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.my_alarm_topic.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# IAM (Setup) Roles and Policies: Securely allow your EC2 instances and services to interact with AWS resources

# IAM Role:
# All EC2 instances must have:

resource "aws_iam_role" "my_ec2_instance_role" {
  name = "ec2_instance_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "my_ec2_instance_role"
  }
}

# IAM Policy:

resource "aws_iam_policy" "my_ec2_basic_policy" {
  name        = "my_ec2_policy"
  path        = "/"
  description = "my_ec2_policy_description"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_policy_attach" {
  role       = aws_iam_role.my_ec2_instance_role.name
  policy_arn = aws_iam_policy.my_ec2_basic_policy.arn
}

resource "aws_iam_instance_profile" "my_ec2_instance_profile" {
  # This instance profile will be used by Jenkins, Monitoring, Scanner
    # Jenkins: Needs S3, logs, Terraform CLI, etc.
    # Monitoring: Sends metrics/logs to CloudWatch
    # Scanner: 	Downloads CVE data, uploads reports
  name = "my_ec2_instance_profile_description"
  role = aws_iam_role.my_ec2_instance_role.name
}