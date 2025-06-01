#!/bin/bash

exec > >(tee /var/log/userdata-scanner.log | logger -t userdata -s 2>/dev/console) 2>&1

# Wait until network is available
until ping -c1 archive.ubuntu.com &>/dev/null; do
  echo "Waiting for internet connection..."
  sleep 2
done

apt update && apt -y upgrade
apt install -y unzip curl openjdk-17-jre-headless git ufw

# OWASP Dependency-Check
mkdir -p /opt/owasp
cd /opt/owasp
curl -L -o dependency-check.zip https://github.com/jeremylong/DependencyCheck/releases/latest/download/dependency-check-8.4.0-release.zip
unzip dependency-check.zip
ln -s /opt/owasp/dependency-check/bin/dependency-check.sh /usr/local/bin/dependency-check.sh

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


# Add Bastion and Jenkins ssh connection internally:

mkdir -p /home/ubuntu/.ssh
echo "${bastion_internal_pubkey}" >> /home/ubuntu/.ssh/authorized_keys
echo "${jenkins_internal_pubkey}" >> /home/ubuntu/.ssh/authorized_keys
chown -R ubuntu:ubuntu /home/ubuntu/.ssh
chmod 600 /home/ubuntu/.ssh/authorized_keys

# Docker (for trivy analysis)

apt-get install -y docker.io
systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu


## Node Exporter for Prometheus:

# Install Node Exporter
useradd --no-create-home --shell /bin/false node_exporter
wget https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz
tar xvfz node_exporter-1.6.1.linux-amd64.tar.gz
cp node_exporter-1.6.1.linux-amd64/node_exporter /usr/local/bin/
chown node_exporter:node_exporter /usr/local/bin/node_exporter

# Create systemd service
cat <<EOF > /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl enable node_exporter
systemctl start node_exporter