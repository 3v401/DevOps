#!/bin/bash

exec > >(tee /var/log/userdata-scanner.log | logger -t userdata -s 2>/dev/console) 2>&1

apt update && apt -y upgrade
apt install -y unzip curl openjdk-17-jre-headless git ufw

# OWASP Dependency-Check
mkdir -p /opt/owasp
cd /opt/owasp
curl -L -o dependency-check.zip https://github.com/jeremylong/DependencyCheck/releases/latest/download/dependency-check-8.4.0-release.zip
unzip dependency-check.zip
ln -s dependency-check/bin/dependency-check.sh /usr/local/bin/dependency-check

# OWASP ZAP (Daemon mode)
apt install -y snapd
snap install zaproxy --classic

# Trivy (for Docker/image scanning)
apt install -y wget
wget https://github.com/aquasecurity/trivy/releases/latest/download/trivy_0.50.1_Linux-64bit.deb
dpkg -i trivy_0.50.1_Linux-64bit.deb

# Scanner scripts dir
mkdir -p /opt/scanner/scripts

# Set up firewall rules
# Enable incoming SSH inbound only
ufw allow OpenSSH
ufw --force enable
