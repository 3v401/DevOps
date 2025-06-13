# ----------------------------------------------------------------
# providers.tf
# ----------------------------------------------------------------

# ---------------------------------------------------------------- Local variables
locals {
    env         = "staging"
    region      = "eu-north-1"
    zone1       = "eu-north-1a"
    zone2       = "eu-north-1b"
    eks_name    = "eks_demo"
    eks_version     = "1.33"
}

# ---------------------------------------------------------------- Providers

provider "aws" {
    region      = local.region
}

terraform {
    required_version = ">=1.0"

    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 5.49"
        }
    }
}

# ----------------------------------------------------------------
# datasources.tf
# ----------------------------------------------------------------

# AMI:

data "aws_ami" "my_main_ubuntu_EC2_data" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

# ----------------------------------------------------------------
# vpc.tf
# ----------------------------------------------------------------

# 1 VPC:

resource "aws_vpc" "my_main_vpc" {
    cidr_block = "10.0.0.0/16"

    enable_dns_support = true
    enable_dns_hostnames = true

    tags = {
        Name = "${local.env}-main"
    }
}

# 1 INTERNET GATEWAY:

resource "aws_internet_gateway" "my_main_igw" {
    vpc_id = aws_vpc.my_main_vpc.id

    tags = {
        Name = "${local.env}-igw"
    }
}

# ---------------------------------------------------------------- SUBNETS
# 4 SUBNETS:

# Private subnet 1
resource "aws_subnet" "my_private_subnet_1" {
  vpc_id                  = aws_vpc.my_main_vpc.id
  # For Jenkins + Scanner (OWASP)
  cidr_block          = "10.0.0.0/19"
  availability_zone   = local.zone1
  
  # map_public_ip_on_launch = false
  
    tags = {
        "Name"                                                 = "${local.env}-private-${local.zone1}"
        "kubernetes.io/role/internal-elb"                      = "1"
        "kubernetes.io/cluster/${local.env}-${local.eks_name}" = "owned"
    }
}

# Private subnet 2
resource "aws_subnet" "my_private_subnet_2" {
  vpc_id                  = aws_vpc.my_main_vpc.id
  # For monitoring
  cidr_block              = "10.0.32.0/19"
  # map_public_ip_on_launch = false
  availability_zone   = local.zone2

  tags = {
      "Name"                                                 = "${local.env}-private-${local.zone2}"
      "kubernetes.io/role/internal-elb"                      = "1"
      "kubernetes.io/cluster/${local.env}-${local.eks_name}" = "owned"
  }
}

# Public subnet 1:
resource "aws_subnet" "my_public_subnet_1" {
  vpc_id                  = aws_vpc.my_main_vpc.id
  # For BASTION host
  cidr_block              = "10.0.64.0/19"
  map_public_ip_on_launch = true
  availability_zone       = local.zone1

  tags = {
    "Name"                                                  = "${local.env}-public=${local.zone1}"
    "kubernetes.io/role/elb"                                = "1"
    "kubernetes.io/cluster/${local.env}-${local.eks_name}"  = "owned"
  }
}

# Public subnet 2:
resource "aws_subnet" "my_public_subnet_2" {
  vpc_id                  = aws_vpc.my_main_vpc.id
  # For API ec2 instance
  cidr_block              = "10.0.96.0/19"
  map_public_ip_on_launch = true
  availability_zone       = local.zone2

  tags = {
    "Name"                                                  = "${local.env}-public=${local.zone2}"
    "kubernetes.io/role/elb"                                = "1"
    "kubernetes.io/cluster/${local.env}-${local.eks_name}"  = "owned"
  }
}

# ---------------------------------------------------------------- NAT Gateway
# Translates private virtual machine IP addresses into public ones to provide internet access to private subnets
# (Allow private subnets to reach the internet)

# Static public IP
resource "aws_eip" "nat" {
    domain = "vpc"

    tags = {
        Name = "${local.env}-nat"
    }
}

resource "aws_nat_gateway" "nat" {
  # NAT Gateways must always be created in a public subnet.
  # NAT Gateway needs public internet access to relay outbound traffic from private subnets.
  # It uses the Internet Gateway, so it must be in a subnet that’s publicly routed.
  allocation_id = aws_eip.nat.id
  subnet_id = aws_subnet.my_public_subnet_1.id

  tags = {
    Name = "${local.env}-nat"
  }

  depends_on = [ aws_internet_gateway.my_main_igw ]
}

# ---------------------------------------------------------------- Route Tables

# 2 ROUTE TABLES:

# Private route table:

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.my_main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
      Name    = "${local.env}-private"
  }
}

# Public route table:

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.my_main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_main_igw.id
  }

  tags = {
      Name = "${local.env}-public"
  }
}

# Assign the route table to the private subnets (zone1 and 2)
resource "aws_route_table_association" "private_zone1" {
  subnet_id      = aws_subnet.my_private_subnet_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_zone2" {
  subnet_id      = aws_subnet.my_private_subnet_2.id
  route_table_id = aws_route_table.private.id
}

# Assign the route table to the public subnets (zone1 and 2)
resource "aws_route_table_association" "public_zone1" {
  subnet_id      = aws_subnet.my_public_subnet_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_zone2" {
  subnet_id      = aws_subnet.my_public_subnet_2.id
  route_table_id = aws_route_table.public.id
}

# -------------------------------------------------------------------------------------------------------------------------------- API EIP
# API EIP (Elastic IP) for API EC2 instance
# This  EIP will be used for CloudFlare to point your A record

resource "aws_eip" "api_eip" {
  tags = {
    Name = "api_static_ip"
  }
}

resource "aws_eip_association" "api_eip_assoc" {
  instance_id   = aws_instance.my_api_EC2_instance.id
  allocation_id = aws_eip.api_eip.id
}

# -------------------------------------------------------------------------------------------------------------------------------- ALB

# ALB for Jenkins access to GitHub Webhooks:

resource "aws_lb" "JENKINS_alb" {
  name           = "JENKINS-alb"
  internal       = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.sg_ALB_JENKINS.id]
  subnets         = [
    aws_subnet.my_public_subnet_1.id,
    aws_subnet.my_public_subnet_2.id
  ]

  tags = {
    Name = "Jenkins alb"
  }
}

# ALB Listener with path filtering
# Listens the traffic on a specific port and routes it to the right target group

resource "aws_lb_listener" "JENKINS_alb_listener" {
  load_balancer_arn     = aws_lb.JENKINS_alb.arn
  port                  = 80
  protocol              = "HTTP"

  default_action {
    type                = "fixed-response"
    fixed_response {
      content_type      = "text/plain"
      message_body      = "Forbidden"
      status_code       = "403"
    } 
  }

  tags = {
    Name = "Return 403 Forbidden for all request by default"
  }
}

# ALB Listener Rule for Webhook
# Only when path is /github-webhook/, it goes to Jenkins
# Any other request (e.g., '/', '/login') gets blocked with 403
resource "aws_lb_listener_rule" "JENKINS_alb_webhook_rule" {
  listener_arn          = aws_lb_listener.JENKINS_alb_listener.arn
  priority              = 1
  
  action {
    type                = "forward"
    target_group_arn    = aws_lb_target_group.JENKINS_alb_tg.arn
  }

  condition {
    path_pattern {
      values            = ["/github-webhook"]
    }
  }
}

resource "aws_lb_listener_rule" "JENKINS_allow_admin_ui" {
  listener_arn = aws_lb_listener.JENKINS_alb_listener.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.JENKINS_alb_tg.arn
  }

  condition {
    source_ip {
      values = [var.my_ip]
    }
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}


# ALB Target Group: Bridge between the ALB and the backend instance
# The Target Group is where the ALB forwards requests

resource "aws_lb_target_group" "JENKINS_alb_tg" {
  name                  = "JENKINS-alb-tg"
  port                  = 8080
  protocol              = "HTTP"
  vpc_id                = aws_vpc.my_main_vpc.id

  health_check {
    path                  = "/"
    interval              = 30
    timeout               = 5
    healthy_threshold     = 2
    unhealthy_threshold   = 2
    matcher               = "200-399"
  }

  target_type             = "instance"
}

# Register Jenkins EC2 to Target group

resource "aws_lb_target_group_attachment" "JENKINS_alb_attachment" {
  target_group_arn      = aws_lb_target_group.JENKINS_alb_tg.arn
  target_id             = aws_instance.my_jenkins_EC2_instance.id
  port                  = 8080
}

# ----------------------------------------------------------------
# iam.tf
# ----------------------------------------------------------------

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

# ---------------------------------------------------------------- Control Plane iam role EKS

resource "aws_iam_role" "eks" {
  name = "${local.env}-${local.eks_name}-eks-cluster"

  assume_role_policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "sts:AssumeRole",
            "Principal": {
                "Service": "eks.amazonaws.com"
            }
        }
    ]
}
POLICY
}

# Attach AmazonEKSClusterPolicy to the IAM role
resource "aws_iam_role_policy_attachment" "eks" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks.name
}

# ---------------------------------------------------------------- K8s Node iam role Group

resource "aws_iam_role" "nodes" {
    name = "${local.env}-${local.eks_name}-eks-nodes"
    assume_role_policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "sts:AssumeRole",
            "Principal": {
                "Service": "ec2.amazonaws.com"
            }
        }
    ]
}
POLICY
}

# ---------------------------------------------------------------- Attach IAM Policies to the Nodes

resource "aws_iam_role_policy_attachment" "amazon_eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.nodes.name
}

resource "aws_iam_role_policy_attachment" "amazon_eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.nodes.name
}

resource "aws_iam_role_policy_attachment" "amazon_ec2_container_registry_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.nodes.name
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
  # This instance profile will be used by Jenkins, Monitoring, Scanner, Builder
    # Jenkins: Needs S3, logs, Terraform CLI, etc.
    # Monitoring: Sends metrics/logs to CloudWatch
    # Scanner: 	Downloads CVE data, uploads reports
    # Builder: Sends Docker Image to DockerHub
  name = "my_ec2_instance_profile_description"
  role = aws_iam_role.my_ec2_instance_role.name
}

# resource "aws_iam_policy_attachment" "ALB_controller_policy_attachment" {
#   name       = "ALB controller policy attachment"
#   roles      = [aws_iam_role.ALB_controller.name]
#   policy_arn = aws_iam_policy.alb_controller_policy.arn
# }

# Downloaded the following policy in Terraform path:
# curl -o iam_policy_alb_controller.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
# It creates the IAM policy required to let the AWS LB Controller manage ALBs in the EKS cluster

resource "aws_iam_policy" "alb_controller_policy" {
  name            = "AWSLoadBalancerControllerIAMPolicy"
  policy          = file("${path.module}/iam_policy_alb_controller.json")
}

# resource "aws_iam_policy_attachment" "alb_controller_attach" {
#   name            = "ALBControllerPolicyAttachment"
#   roles           = [aws_iam_role.ALB_controller.name]
#   policy_arn      = aws_iam_policy.alb_controller_policy.arn
# }

# ----------------------------------------------------------------
# instances.tf
# ----------------------------------------------------------------

# 5 EC2 instances + Keys:

# 1st instance: Bastion Host + Key pair---------------------------------------------------BASTION
# Purpose: Secure access point to private instances (via SSH)
# Install: Only SSH

resource "aws_key_pair" "my_bastion_key_auth" {
  key_name   = "my_bastion_key"
  public_key = file(var.bastion_public_key_path)
}

# RSA key of size 4096 bits
# This key will be used to connect internally Bastion to other EC2
# via SSH
resource "tls_private_key" "bastion_internal" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "bastion_private_key" {
  content  = tls_private_key.bastion_internal.private_key_pem
  filename = "${path.module}/bastion_internal.pem"
  file_permission = "0600"
}

locals {
  bastion_internal_pubkey = tls_private_key.bastion_internal.public_key_openssh
}

data "template_file" "bastion_userdata" {
  template = file("${path.module}/userdata_bastion.tpl")
  vars = {
    bastion_internal_pem = tls_private_key.bastion_internal.private_key_pem
    bastion_internal_pubkey = tls_private_key.bastion_internal.public_key_openssh
  }
}


resource "aws_instance" "my_bastion_EC2_instance" {
  ami           = data.aws_ami.my_main_ubuntu_EC2_data.id
  instance_type = "t3.micro"
  key_name = aws_key_pair.my_bastion_key_auth.id
  vpc_security_group_ids = [aws_security_group.sg_BASTION.id]
  subnet_id = aws_subnet.my_public_subnet_1.id
  user_data = data.template_file.bastion_userdata.rendered
  # configuration file to bootstrap the server

  root_block_device {
    volume_size = 10
  }

  tags = {
    Name = "bastion-server"
  }
}

# 2nd instance: Public API server + Key pair---------------------------------------------------API
# Purpose: Hosts your public-facing application (API)
# Install Nginx, backendapp and Certbot

resource "aws_key_pair" "my_api_key_auth" {
  key_name   = "my_api_key"
  public_key = file(var.api_public_key_path)
}

data "template_file" "api_userdata" {
  template = file("${path.module}/userdata_api.tpl")
  vars = {
    bastion_internal_pubkey = local.bastion_internal_pubkey
    jenkins_internal_pubkey = local.jenkins_internal_pubkey
  }
}

resource "aws_instance" "my_api_EC2_instance" {
  ami           = data.aws_ami.my_main_ubuntu_EC2_data.id
  instance_type = "t3.micro"
  key_name = aws_key_pair.my_api_key_auth.id
  vpc_security_group_ids = [aws_security_group.sg_API.id]
  subnet_id = aws_subnet.my_public_subnet_2.id
  user_data = data.template_file.api_userdata.rendered
  # configuration file to bootstrap the server + .pub key to allow ssh connection
  # from Bastion to this EC2 instance.

  root_block_device {
    volume_size = 10
  }

  tags = {
    Name = "api-server"
  }
}

# 3rd instance: Jenkins server + Key pair---------------------------------------------------JENKINS
# Purpose: Automates build, test, deploy
# Install : Jenkins, Git, Docker

resource "aws_key_pair" "my_jenkins_key_auth" {
  key_name   = "my_jenkins_key"
  public_key = file(var.jenkins_public_key_path)
}

# RSA key of size 4096 bits
# This key will be used to connect internally Jenkins to other EC2
# instances via SSH during Pipeline Stages
resource "tls_private_key" "jenkins_internal" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "jenkins_private_key" {
  content  = tls_private_key.jenkins_internal.private_key_pem
  filename = "${path.module}/jenkins_internal.pem"
  file_permission = "0600"
}

locals {
  jenkins_internal_pubkey = tls_private_key.jenkins_internal.public_key_openssh
}

data "template_file" "jenkins_userdata" {
  template = file("${path.module}/userdata_jenkins.tpl")
  vars = {
    jenkins_internal_pem = tls_private_key.jenkins_internal.private_key_pem
    jenkins_internal_pubkey = tls_private_key.jenkins_internal.public_key_openssh
    bastion_internal_pubkey = local.bastion_internal_pubkey
  }
}

resource "aws_instance" "my_jenkins_EC2_instance" {
  ami           = data.aws_ami.my_main_ubuntu_EC2_data.id
  instance_type = "t3.micro"
  key_name = aws_key_pair.my_jenkins_key_auth.id
  vpc_security_group_ids = [aws_security_group.sg_JENKINS.id]
  subnet_id = aws_subnet.my_private_subnet_1.id
  user_data = data.template_file.jenkins_userdata.rendered
  # configuration file to bootstrap the server + .pub key to allow ssh connection
  # from Bastion to this EC2 instance.
  iam_instance_profile = aws_iam_instance_profile.my_ec2_instance_profile.name

  root_block_device {
    volume_size = 10
  }

  tags = {
    Name = "jenkins-server"
  }
}

# 4th instance: OWASP Scanner + Key pair---------------------------------------------------SCANNER
# Purpose: Runs vulnerability scanning (DevSecOps)
# Install: OWASP Dependency-Check, ZAP or Trivy

resource "aws_key_pair" "my_scanner_key_auth" {
  key_name   = "my_scanner_key"
  public_key = file(var.scanner_public_key_path)
}

data "template_file" "scanner_userdata" {
  template = file("${path.module}/userdata_scanner.tpl")
  vars = {
    bastion_internal_pubkey = local.bastion_internal_pubkey
    jenkins_internal_pubkey = local.jenkins_internal_pubkey
  }
}

resource "aws_instance" "my_scanner_EC2_instance" {
  ami           = data.aws_ami.my_main_ubuntu_EC2_data.id
  instance_type = "t3.micro"
  key_name = aws_key_pair.my_scanner_key_auth.id
  vpc_security_group_ids = [aws_security_group.sg_SCANNER.id]
  subnet_id = aws_subnet.my_private_subnet_1.id
  user_data = data.template_file.scanner_userdata.rendered
  # configuration file to bootstrap the server + .pub key to allow ssh connection
  # from Bastion to this EC2 instance.
  iam_instance_profile = aws_iam_instance_profile.my_ec2_instance_profile.name

  root_block_device {
    volume_size = 10
  }

  tags = {
    Name = "scanner-server"
  }
}

# 5th instance: Monitorin + Key pair---------------------------------------------------MONITORING
# Purpose: Aggregates logs, metrics, alerts
# Install: Prometheus, Grafana, Loki, or ELK Stack

resource "aws_key_pair" "my_monitoring_key_auth" {
  key_name   = "my_monitoring_key"
  public_key = file(var.monitoring_public_key_path)
}

data "template_file" "monitoring_userdata" {
  template = file("${path.module}/userdata_monitoring.tpl")
  vars = {
    bastion_internal_pubkey = local.bastion_internal_pubkey
  }
}

resource "aws_instance" "my_monitoring_EC2_instance" {
  ami           = data.aws_ami.my_main_ubuntu_EC2_data.id
  instance_type = "t3.micro"
  key_name = aws_key_pair.my_monitoring_key_auth.id
  vpc_security_group_ids = [aws_security_group.sg_MONITORING.id]
  subnet_id = aws_subnet.my_private_subnet_2.id
  user_data = data.template_file.monitoring_userdata.rendered
  # configuration file to bootstrap the server + .pub key to allow ssh connection
  # from Bastion to this EC2 instance.
  iam_instance_profile = aws_iam_instance_profile.my_ec2_instance_profile.name

  root_block_device {
    volume_size = 10
  }

  tags = {
    Name = "monitoring-server"
  }
}

# 6th instance: Builder + Key pair---------------------------------------------------BUILDER
# Purpose: Builds images, tags it and uploads it to DockerHub
# Install: AWS CLI, Docker, kubectl

resource "aws_key_pair" "my_builder_key_auth" {
  key_name   = "my_builder_key"
  public_key = file(var.builder_public_key_path)
}

data "template_file" "builder_userdata" {
  template = file("${path.module}/userdata_builder.tpl")
  vars = {
    bastion_internal_pubkey = local.bastion_internal_pubkey
    jenkins_internal_pubkey = local.jenkins_internal_pubkey
    VPC_ID                  = aws_vpc.my_main_vpc.id
    CLOUDFLARE_TOKEN        = var.CLOUDFLARE_TOKEN
    MY_DOMAIN               = var.MY_DOMAIN
  }
}

resource "aws_instance" "my_builder_EC2_instance" {
  ami           = data.aws_ami.my_main_ubuntu_EC2_data.id
  instance_type = "t3.micro"
  key_name = aws_key_pair.my_builder_key_auth.id
  vpc_security_group_ids = [aws_security_group.sg_BUILDER.id]
  subnet_id = aws_subnet.my_private_subnet_1.id
  user_data = data.template_file.builder_userdata.rendered
  # configuration file to bootstrap the server + .pub key to allow ssh connection
  # from Bastion to this EC2 instance.
  # iam_instance_profile = aws_iam_instance_profile.builder_profile.name

  root_block_device {
    volume_size = 10
  }

  tags = {
    Name = "builder-server"
  }
}

# 7th Instance: EKS --------------------------------------------------- EKS Cluster

resource "aws_eks_cluster" "eks" {
    name = "${local.env}-${local.eks_name}"
    version = local.eks_version
    role_arn = aws_iam_role.eks.arn

    vpc_config {
      endpoint_private_access = false
      endpoint_public_access = true

      subnet_ids = [
        aws_subnet.my_private_subnet_1.id,
        aws_subnet.my_private_subnet_2.id
      ]
    }

    access_config {
        authentication_mode         = "API"
        bootstrap_cluster_creator_admin_permissions = true
    }

    depends_on = [
        aws_iam_role_policy_attachment.eks
    ]
}

# ---------------------------------------------------------------- Node Group

resource "aws_eks_node_group" "general" {
  
  cluster_name = aws_eks_cluster.eks.name
  version      = local.eks_version
  node_group_name = "general"
  node_role_arn = aws_iam_role.nodes.arn

  subnet_ids = [
    aws_subnet.my_private_subnet_1.id,
    aws_subnet.my_private_subnet_2.id
  ]

  capacity_type = "ON_DEMAND"
  instance_types = ["t3.medium"]

  scaling_config {
    desired_size = 2
    max_size = 3
    min_size = 1
  }
  update_config {
    max_unavailable = 1
  }

  labels = {
    role = "general"
  }

  depends_on = [ 
    aws_iam_role_policy_attachment.amazon_eks_worker_node_policy,
    aws_iam_role_policy_attachment.amazon_eks_cni_policy,
    aws_iam_role_policy_attachment.amazon_ec2_container_registry_read_only,
   ]

   lifecycle {
     ignore_changes = [ scaling_config[0].desired_size ]
   }
}

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

# ----------------------------------------------------------------
# Cloudwatch.tf
# ----------------------------------------------------------------

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
  alarm_actions = [aws_sns_topic.my_alarm_topic.arn]
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

# ----------------------------------------------------------------
# output.tf
# ----------------------------------------------------------------

output "scanner_private_ip" {
    value = aws_instance.my_scanner_EC2_instance.private_ip
}

output "builder_private_ip" {
    value = aws_instance.my_builder_EC2_instance.private_ip
}

output "monitoring_private_ip" {
    value = aws_instance.my_monitoring_EC2_instance.private_ip
}

output "api_public_ip" {
    value = aws_instance.my_api_EC2_instance.public_ip
}

output "bastion_public_ip" {
    value = aws_instance.my_bastion_EC2_instance.public_ip
}

output "jenkins_webhook_url" {
    value = "http://${aws_lb.JENKINS_alb.dns_name}/github-webook"
    description = "Public URL to set as the GitHub webhook (domain is dns ALB)"
}

data "template_file" "prometheus_config" {
    template = file("${path.module}/prometheus.yml.tpl")
    vars = {
        API_IP                  = aws_instance.my_api_EC2_instance.private_ip
        SCANNER_IP              = aws_instance.my_scanner_EC2_instance.private_ip
        JENKINS_IP              = aws_instance.my_jenkins_EC2_instance.private_ip
        BUILDER_IP              = aws_instance.my_builder_EC2_instance.private_ip
    }
}

resource "local_file" "prometheus_config" {
    content                     = data.template_file.prometheus_config.rendered
    filename                    = "${path.module}/prometheus.yml"
}

# ----------------------------------------------------------------
# storage.tf
# ----------------------------------------------------------------

# S3 bucket:
# Goal: Store logs

resource "aws_s3_bucket" "my_s3_bucket" {
  bucket = "myowaspproject3v401-logs"

  tags = {
    Name        = "My bucket"
    Environment = "Dev"
  }
}

resource "aws_ebs_volume" "jenkins_data" {
  availability_zone = "eu-north-1a"
  size              = 15
  type              = "gp3"

  tags = {
    Name = "jenkins_data_volume"
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_volume_attachment" "jenkins_data_attachment" {
  device_name = "/dev/xvdf"
  # Linux path to the created EBS volume
  volume_id   = aws_ebs_volume.jenkins_data.id
  instance_id = aws_instance.my_jenkins_EC2_instance.id
  force_detach = true
}

# ----------------------------------------------------------------
# variables.tf
# ----------------------------------------------------------------

variable "my_ip" {
  description = "Your public IP with /32 mask"
  type        = string
}

variable "alert_email" {
  description = "Email address to receive CloudWatch alerts"
  type        = string
}

variable "bastion_public_key_path" {
  description = "Path to the bastion public key"
  type        = string
}

variable "api_public_key_path" {
  description = "Path to the API public key"
  type        = string
}

variable "jenkins_public_key_path" {
  description = "Path to the jenkins public key"
  type        = string
}

variable "scanner_public_key_path" {
  description = "Path to the scanner public key"
  type        = string
}

variable "monitoring_public_key_path" {
  description = "Path to the monitoring public key"
  type        = string
}

variable "builder_public_key_path" {
  description = "Path to the builder public key"
  type        = string
}

variable "MY_DOMAIN" {
  description = "Target domain of the project"
  type        = string
}

variable "CLOUDFLARE_TOKEN" {
  description = "Cloudflre token for domain to pod connection"
  type        = string
}