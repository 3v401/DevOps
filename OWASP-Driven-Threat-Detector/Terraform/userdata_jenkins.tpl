#!/bin/bash

# Saves all output data setup logs in userdata-jenkins.log
# >(command) runs a command in a subshell
exec > >(tee /var/log/userdata-jenkins.log | logger -t userdata -s 2>/dev/console) 2>&1

# System update
apt update && apt -y upgrade

# Install dependencies
apt install -y openjdk-17-jdk curl gnupg2 ufw

# Add Jenkins repo and key
mkdir -p /etc/apt/keyrings
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | tee /etc/apt/keyrings/jenkins-keyring.asc > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" > /etc/apt/sources.list.d/jenkins.list

# Install Jenkins
apt update
apt install -y jenkins

# Start Jenkins service
systemctl enable jenkins
systemctl start jenkins

# Open firewall ports
ufw allow OpenSSH
# Jenkins runs on port 8080 by default (to open from browser)
ufw allow 8080
# HTTP (used during plugin installations)
ufw allow 80
# HTTPS (used for when setting SSL)
ufw allow 443
ufw --force enable

# Store Jenkins initial admin password in file
echo "Jenkins initial admin password:" > /home/ubuntu/jenkins_password.txt
cat /var/lib/jenkins/secrets/initialAdminPassword >> /home/ubuntu/jenkins_password.txt
# Set file ownership to ubuntu (default user)
chown ubuntu:ubuntu /home/ubuntu/jenkins_password.txt
# Only the owner (ubuntu) can read + write (others no access)
chmod 600 /home/ubuntu/jenkins_password.txt
