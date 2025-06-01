#!/bin/bash
# Add Bastion and Jenkins ssh connection internally:
mkdir -p /home/ubuntu/.ssh
echo "${bastion_internal_pubkey}" >> /home/ubuntu/.ssh/authorized_keys
echo "${jenkins_internal_pubkey}" >> /home/ubuntu/.ssh/authorized_keys
chown -R ubuntu:ubuntu /home/ubuntu/.ssh
chmod 600 /home/ubuntu/.ssh/authorized_keys

# Wait until network is available
until ping -c1 archive.ubuntu.com &>/dev/null; do
  echo "Waiting for internet connection..."
  sleep 2
done

# Docker
apt update -y
apt-get install -y docker.io
usermod -aG docker ubuntu
systemctl enable docker
systemctl start docker

# AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/

# Install helm
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

# EKS charts repository
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Create namespace for controller
kubectl create namespace kube-system

# Create IAM OIDC provider

# Install ALB Controller via Helm

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n kube-system \
    --set clusterName=API_EKS_ThreatGPT \
    --set serviceAccount.create = false \
    --set region = eu-north-1 \
    --set vpcId = ${VPC_ID} \
    --set serviceAccount.name = aws-load-balancer-controller

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
