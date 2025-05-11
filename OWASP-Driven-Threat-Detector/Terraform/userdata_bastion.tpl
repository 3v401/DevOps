#!/bin/bash

# Log setup for debugging
# Minimal configuration to minimize attack surface
exec > >(tee /var/log/userdata-bastion.log | logger -t userdata -s 2>/dev/console) 2>&1

apt update && apt -y upgrade
apt install -y openssh-server
# fail2ban for brute-force protection
apt install -y fail2ban
ufw allow OpenSSH
ufw --force enable

# Add Bastion ssh connection internally:

mkdir -p /home/ubuntu/.ssh
echo "${bastion_internal_pubkey}" >> /home/ubuntu/.ssh/authorized_keys
chown -R ubuntu:ubuntu /home/ubuntu/.ssh
chmod 600 /home/ubuntu/.ssh/authorized_keys

# echo does not handle multiline comments well:
cat <<EOF > /home/ubuntu/.ssh/bastion_internal.pem
${bastion_internal_pem}
EOF

chown ubuntu:ubuntu /home/ubuntu/.ssh/bastion_internal.pem
chmod 600 /home/ubuntu/.ssh/bastion_internal.pem