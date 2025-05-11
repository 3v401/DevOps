#!/bin/bash

# Save all output data setup logs in userdata-jenkins.log
# >(command) runs a command in a subshell
exec > >(tee /var/log/userdata-jenkins.log | logger -t userdata -s 2>/dev/console) 2>&1

apt update && apt -y upgrade
apt install -y openjdk-17-jdk curl gnupg2 ufw

# Add Jenkins repo, key and install
mkdir -p /etc/apt/keyrings
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | tee /etc/apt/keyrings/jenkins-keyring.asc > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" > /etc/apt/sources.list.d/jenkins.list
apt update
apt install -y jenkins

# Start Jenkins service
systemctl enable jenkins
systemctl start jenkins

# Open firewall ports
ufw allow OpenSSH
# Jenkins runs on port 8080 by default (to open from browser)
ufw allow 8080
# HTTP used during plugin installation
ufw allow 80
# HTTPS used when setting SSL
ufw allow 443
ufw --force enable

# Store Jenkins initial admin password in file
echo "Jenkins initial admin password:" > /home/ubuntu/jenkins_password.txt
cat /var/lib/jenkins/secrets/initialAdminPassword >> /home/ubuntu/jenkins_password.txt
# Set file ownership to ubuntu (default user)
chown ubuntu:ubuntu /home/ubuntu/jenkins_password.txt
# Only the owner (ubuntu) can read + write (others no access)
chmod 600 /home/ubuntu/jenkins_password.txt

# Format and mount EBS (if first time)
# xvdf1 (partition 1 on the disk)
if [ ! -e /dev/xvdf1 ]; then
    mkfs -t ext4 /dev/xvdf
    # If the partition does not exist -> Format the whole
    # volume with the ext4 filesystem
fi

mkdir -p /var/lib/jenkins
mount /dev/xvdf /var/lib/jenkins
echo "/dev/xvdf /var/lib/jenkins ext4 defaults, nofail 0 2" >> /etc/fstab
# /dev/xvdf: Device to mount
# /var/lib/jenkins: Where to mount it
# ext4: Filesystem type
# nofail: Prevent boot failure if volume is missing
# 0 (skip dump) 2 (run fsck, disk check second)

# Add Bastion ssh connection internally:

mkdir -p /home/ubuntu/.ssh
echo "${bastion_internal_pubkey}" >> /home/ubuntu/.ssh/authorized_keys
chown -R ubuntu:ubuntu /home/ubuntu/.ssh
chmod 600 /home/ubuntu/.ssh/authorized_keys