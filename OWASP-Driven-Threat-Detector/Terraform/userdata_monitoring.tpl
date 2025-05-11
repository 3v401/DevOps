#!/bin/bash

# Log setup
exec > >(tee /var/log/userdata-monitoring.log | logger -t userdata -s 2>/dev/console) 2>&1

apt update && apt -y upgrade
apt install -y curl wget gnupg2 software-properties-common apt-transport-https ufw

# Prometheus:
useradd --no-create-home --shell /bin/false prometheus
mkdir /etc/prometheus /var/lib/prometheus

cd /tmp
wget https://github.com/prometheus/prometheus/releases/download/v2.48.1/prometheus-2.48.1.linux-amd64.tar.gz
tar xvf prometheus-2.48.1.linux-amd64.tar.gz
cd prometheus-2.48.1.linux-amd64

cp prometheus /usr/local/bin/
cp promtool /usr/local/bin/
cp -r consoles/ console_libraries/ /etc/prometheus/

cat <<EOF > /etc/prometheus/prometheus.yml
global:
  scrape_interval: 15s
scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets: ['localhost:9090']
EOF

chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus /usr/local/bin/prometheus /usr/local/bin/promtool

cat <<EOF > /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus
After=network.target

[Service]
User=prometheus
ExecStart=/usr/local/bin/prometheus --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/var/lib/prometheus/
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable prometheus
systemctl start prometheus

# Grafana:
wget -q -O - https://packages.grafana.com/gpg.key | apt-key add -
add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
apt update
apt install -y grafana

systemctl enable grafana-server
systemctl start grafana-server

# --- Open Firewall Ports ---
ufw allow OpenSSH
ufw allow 3000    # Grafana UI
ufw allow 9090    # Prometheus UI
ufw --force enable

# Add Bastion ssh connection internally:

mkdir -p /home/ubuntu/.ssh
echo "${bastion_internal_pubkey}" >> /home/ubuntu/.ssh/authorized_keys
chown -R ubuntu:ubuntu /home/ubuntu/.ssh
chmod 600 /home/ubuntu/.ssh/authorized_keys