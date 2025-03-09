We need three servers:

1. Jenkins: name: 'jenkins-server', AMI: Ubuntu 24.04 64bit, Storage: 10gb gp3, Key pair (login): ansible | RSA (pem), Network settings: Type 'All traffic' Protocol 'All' Port range '8080' Sourcetype 'My IP' Source 'X.X.X.X/X', t3.micro.
2. Ansible: name: 'ansible-server', AMI: UBuntu 24.04 64bits, Storage: 10gb gp3, Key pair (login): ansible | RSA (pem), Network settings: Type 'All traffic' Protocol 'All' Port range 'All' Sourcetype 'Anywhere' Source '0.0.0.0/0', t3.micro.
3. Kubernetes: name: 'kubernetes-server', AMI: Ubuntu 24.04 64bit, Storage: 8gb gp3, Key pair (login): ansible | RSA (pem), Network settings: Type 'All traffic' Protocol 'All' Port range 'All' Sourcetype 'Anywhere' Source '0.0.0.0/0', t3.medium
