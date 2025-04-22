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