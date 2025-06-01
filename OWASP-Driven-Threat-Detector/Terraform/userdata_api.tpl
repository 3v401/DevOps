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

