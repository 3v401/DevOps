sudo su
mkdir -p /etc/apt/keyrings
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee /etc/apt/keyrings/jenkins-keyring.asc > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
apt update && apt -y upgrade
apt install -y openjdk-17-jdk
apt install -y jenkins
systemctl status jenkins
ufw status
ufw allow OpenSSH && ufw enable
ufw allow 8080
ufw status
cat /var/lib/jenkins/secrets/initialAdminPassword
