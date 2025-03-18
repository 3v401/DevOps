#!/bin/bash

# Obtain public IP
IP=$(curl -s ifconfig.me)

# Configuration file to edit
CONFIG_FILE="/var/lib/jenkins/jenkins.model.JenkinsLocationConfiguration.xml"

# Substitute IP:
sed -i "s|<jenkinsUrl>.*</jenkinsUrl>|<jenkinsUrl>http://$IP:8080/</jenkinsUrl>|" "$CONFIG_FILE"

# Reload daemon
sudo systemctl daemon-reload

# Restart Jenkins
sudo systemctl restart jenkins
