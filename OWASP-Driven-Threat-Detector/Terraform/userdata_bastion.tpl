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
