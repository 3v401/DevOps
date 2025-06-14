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
  iam_instance_profile = aws_iam_instance_profile.scanner_instance_profile.name


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
    AWS_ACCESS_KEY_ID       = var.AWS_ACCESS_KEY_ID
    AWS_SECRET_ACCESS_KEY   = var.AWS_SECRET_ACCESS_KEY
    OPENAI_API_KEY          = var.OPENAI_API_KEY
    AWS_USER                = var.AWS_USER
  }
}

data "template_file" "eks_deployment" {
  template = file("${path.module}/../Builder/EKS/deployment.yaml.tpl")

  vars = {
    AWS_USER = var.AWS_USER
    OPENAI_API_KEY          = var.OPENAI_API_KEY
  }
}

resource "local_file" "eks_deployment_yaml" {
  content  = data.template_file.eks_deployment.rendered
  filename = "${path.module}/../Builder/EKS/deployment.yaml"
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
  iam_instance_profile = aws_iam_instance_profile.builder_profile.name

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