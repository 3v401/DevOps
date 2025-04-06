# Secure CI/CD pipeline for containerized Tetris Delivery on AWS
#### (Post under development)
##### Project result:

<p align="center">
  <img src="pics/pic29-end.png" alt="pic29" width="345"/>
  <img src="pics/pic30-end.png" alt="pic30" width="320"/>
  <img src="pics/pic31-end.png" alt="pic31" width="315"/>
</p>


# Index:

1. Setting up servers
2. CI/CD
3. Playing Tetris

# Setting up

| Requirements         | Inbound Rules                                        | Description                         | Outbound Rules      | IAM Roles           |
|--------------------|--------------------------------------------------------| ------------------------|---------------------|----------------------|
| **Jenkins-server** | SSH my IP                                              |                         | All traffic 0.0.0.0/0 | No                  |
|                    | SSH Ansible-server internal IP                         |                        |                     |                      |
|                    | SSH Kubernetes-server internal IP                      |                        |                     |                      |
|                    | SSH Github Webhook IPv4                                |                        |                     |                      |
|                    | SSH Github Webhook IPv6                                |                        |                     |                      |
| **Ansible-server** | SSH <-> my IP                                              |                         | All traffic 0.0.0.0/0 | No                  |
|                    | SSH Jenkins-server internal IP                         |                        |                     |                      |
|                    | SSH Kubernetes-server internal IP                      |                        |                     |                      |
| **Kubernetes-server** | SSH my IP                                           |   SSH connection from my IP                     | All traffic 0.0.0.0/0 | K8s-EC2-ELB-Role    |
|                    | SSH Jenkins-server internal IP                         |                        |                     |                      |
|                    | SSH Ansible-server internal IP                         |                        |                     |                      |
|                    | Custom TCP 80 my IP                                    |                        |                     |                      |
|                    | Custom TCP <kubernetes_nodeport> my IP                 |                        |                     |                      |
|                    | Custom TCP <kubernetes_nodeport> LB subnet IPs         |                        |                     |                      |
|                    | Custom TCP 6443 <-> My IP                              |   API Kubernetes       |                     |                      |
| **Load Balancer**  | Custom TCP 80 my IP                                    |                         | All traffic 0.0.0.0/0 | K8s-EC2-ELB-Role    |
|                    | Custom TCP <kubernetes_nodeport> my IP                 |                        |                     |                      |

## Jenkins server

Activate the `jenkins-server` EC2 instance.
Locate your `.pem` file and enable permissions: `chmod 400 <KEYPAIR_FILENAME>`
Connect to your instance: `ssh -i <KEYPAIR_FILENAME> ubuntu@ec2-<PUBLIC_IP>.eu-north-1.compute.amazonaws.com`

![alt text](pics/pic2.png)

You are connected to your jenkins-server!
For Jenkins installation I used the following [tutorial post](https://www.digitalocean.com/community/tutorials/how-to-install-jenkins-on-ubuntu-20-04).

1. Activate root user: `sudo su`
2.  Add the Correct GPG Key: 
```
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee /etc/apt/keyrings/jenkins-keyring.asc > /dev/null
```
3. Add the Jenkins repository to the system's package sources list: `echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null`
4. Update and upgrade the package list: `apt update && apt upgrade`
5. Install Jenkins: `apt install jenkins`
6. Start Jenkins service: `systemctl start jenkins`
7. After installing Jenkins it is probable that it won't work. In my case it was due to missing java (`java --version`). To solve this issue, install Java too: `apt install -y openjdk-17-jdk`. Repeat step 6.
8. Check Jenkins service status*: `systemctl status jenkins`

![alt text](pics/pic3.png)

*`systemctl` is a tool used to manage system services on Linux systems that use systemd. `systemd` is a service manager for Linux, used to boot the system and managing processes.

9. Check if the firewall is inactive: `ufw status`
10. Allow traffic on port 8080 through firewall: `ufw allow 8080`
11. Check if the firewall is inactive: `ufw status`
12. If firewall is inactive (Means all firewall rules were ignored, including the ufw allow 8080 rule), allow OpenSSH and enable it: `sudo ufw allow OpenSSH && ufw enable`

![alt text](pics/pic4.png)

When previous command is run, the `ufw enable` command activated the firewall, making all previously added rules (including 8080) take effect.
13. Check if the firewall is inactive again: `ufw status`.
14. Get the initial Jenkins admin password: `cat /var/lib/jenkins/secrets/initialAdminPassword`

![alt text](pics/pic5.png)

Once you get the password, access the browser, type `<PUBLIC_IP_JENKINS>:<PORT>` and introduce it.

![alt text](pics/pic6.png)

1. Select `Install suggested plugins`.
2. Create first admin user.
3. Save your Jenkins instance configuration: `http://<PUBLIC_IP_JENKINS>:<PORT>/`

![alt text](pics/pic7.png)

Search and install: Dashboard -> Manage Jenkins -> Plugins -> ssh agent

![alt text](pics/pic8.png)

Restart Jenkins after installation is fulfilled.

![alt text](pics/pic9.png)

Jenkins ready!

### Setting persistance on Jenkins

When you turn off your EC2 instance, you will loose access to your Jenkins pipeline, being too slow to be used. It will seem like there are some issues to troubleshoot with Network ACLs, Security groups, Firewalls... Nonetheless, if you followed the exact same process from this post, you have to enable a recurrent update of your last update. For that:

1. Run: `vim /opt/update-jenkins-url.sh` and copy the content of the file `update-jenkins-url.sh` in the repository. Save and exit.
2. Execute `chmod +x /opt/update-jenkins-url.sh`.
3. Run: `sudo vim /opt/startup-tasks.sh`
4. This file will be the main "startup-tasks" that will be executed each time the EC2 instance is started/rebooted. Add:
```
#!/bin/bash

/opt/update-jenkins-url.sh
# Any other script you may need
```
3. Run: `sudo chmod +x /opt/startup-tasks.sh`
4. Run: `sudo vim /etc/systemd/system/startup-tasks.service`
```
[Unit]
Description=Run all custom startup scripts after boot
# The service starts after the network is up
After=network.target

[Service]
# Oneshot: Run the service once and then exit (don't stay active)
Type=oneshot

ExecStart=/opt/startup-tasks.sh

[Install]
# Run automatically while booting
WantedBy=multi-user.target
```
5. Activate the service again: `sudo systemctl daemon-reload && sudo systemctl enable startup-tasks.service`

## Ansible server

(Install Ansible both in Ansible and Kubernetes Server)

Ansible is an open-source automation tool used for configuration management, application deployment, and infrastructure orchestration. It allows managing servers and deployments using YAML-based playbooks. In this example, it will execute tasks on a remote server (the Kubernetes node). Instead of manually logging into the Kubernetes server and running kubectl apply or configurations, Ansible automates this process from a central control node (the "Ansible server"). This is typical in environments where infrastructure as code (IaC) and centralized management are required.

For Ansible server set as:

1. Inbound connections: HTTP/HTTPS Anywhere IPv4 (Description: Internet connection -> EC2), SSH Jenkins IP, My IP (Jenkins, My IP connection)
2. Outbound connections: HTTP/HTTPS Anywhere IPv4 (Description: EC2 -> Internet connection)

For Ansible installation I used the following [tutorial post](https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-ansible-on-ubuntu-20-04).
1. Activate root user: `sudo su`
2. Add the Ansible PPA repository: `apt-add-repository ppa:ansible/ansible`
3. Update package lists to include the new repository and upgrade: `apt update && apt upgrade`
4. Install Ansible: `apt install ansible`

## Kubernetes server

Kubernetes (K8s) is an open-source container orchestration platform used for automating deployment, scaling, and management of containerized applications across multiple nodes. For this section we will install Docker and Kubectl.

### Docker (Install both in Ansible and Kubernetes server)

Docker is an open-source containerization platform that allows developers to package applications and their dependencies into lightweight, portable containers. For Docker installation I used the following [tutorial post](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-on-ubuntu-20-04).

1. Activate root user: `sudo su`
2. Update package lists: `apt update`
3. Install required dependencies for Docker: `apt install apt-transport-https ca-certificates curl software-properties-common`
4. Add the Docker GPG key to verify package authenticity: `curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -`

      i. `-fsSL` : Ensures a silent, fail-safe, and secure download.

      ii. `apt-key add -` : Adds the downloaded GPG key to verify Docker packages.

5. Add the official Docker repository to APT sources: `add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"`
6. Check available Docker versions and repository priority: `apt-cache policy docker-ce`
7. Install Docker CE (Community Edition): `apt install docker-ce`
8. Exit root mode and add your user to the docker group: `sudo usermod -aG docker $USER`
9. Check Docker service status: `systemctl status docker`

![alt text](pics/pic10.png)

### Kubeadm

1. Disable swap:
```
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab
```
2. Update and install containerd
```
sudo apt update
sudo apt install -y containerd
```
3. Generate default config:
```
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
```
4. Use systemd as group driver: `sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml`
5. Restart containerd:
```
sudo systemctl restart containerd
sudo systemctl enable containerd
```
6. Install Kubernetes tools (kubeadm, kubelet, kubectl):
```
sudo apt-get update && sudo apt-get install -y apt-transport-https curl
sudo curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/kubernetes.gpg
echo 'deb https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```
7. ~~Initialize Kubernetes cluster: `sudo kubeadm init --pod-network-cidr=10.244.0.0/16`. `10.244.0.0/16` is the default pod network range required by Flannel.~~
8. ~~If an error is prompted related to missing kernel settings for kubernetes networking (`/proc/sys/net/bridge/bridge-nf-call-iptables` does not exist and `/proc/sys/net/ipv4/ip_forward` is not set to 1) run:~~
```
sudo modprobe br_netfilter
echo 'br_netfilter' | sudo tee /etc/modules-load.d/k8s.conf

echo 'net.bridge.bridge-nf-call-iptables=1' | sudo tee /etc/sysctl.d/k8s.conf
echo 'net.ipv4.ip_forward=1' | sudo tee -a /etc/sysctl.d/k8s.conf
sudo sysctl --system
```
~~This commands load the br_netfilter module and ensures it's loaded on boot, then sets required kernel params for Kubernetes networking.
9. Set up kubectl access for your user:~~
```
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### Enable Load Balancer

To expose the Tetris app (contained in a K8s Pod) through AWS, usually the easiest path is to set the Service with a LoadBalancer. This way K8s will create an ELB (Classic, NLB or ALB) and it will associate it to the nodes that run the service. An Elastic LOad Balancer (ELB) is an AWS service that acts as public door entrance to your applications. It:

1. Receives internet traffic to the servers
2. Redirect traffic to the servers
3. Distributes the traffic between several instances/pods to avoid high traffic weight.

In our application, Kubernetes will ask AWS to create an Classic Load Balancer (CLB) automatically. This CLB will have a public DNS to access from the browser. To enable a CLB go where the `Service.yml` file is located.

For an self-organized K8s EC2 instance being able to create and administrate AWS resources (e.g., LB, EBS volumns, etc) there are two requirements:

 1. ~~Install containerd.~~
 2. `kube-controller-manager` (control plane) must have `cloud-provider` set to `aws`.
 3. Install external cloud provider (AWS Cloud Controller Manager, CCM)
 4. The EC2 instance that runs the control plane must have an IAM role with certain permissions.

This way, when K8s (`kube-controller-manager`) calls the AWS API (to create the LB), it will use the IAM role assigned.


###### containerd

1. ~~Install via: `sudo apt-get install -y containerd`~~
2. Verify status: `sudo systemctl status containerd`
3. ~~Check whether containerd uses `CRI v1`:~~
```
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
```
~~4. Open the file and edit: `vim /etc/containerd/config.toml`~~
```
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
  SystemdCgroup = true
```
~~5. Reboot containerd: `sudo systemctl restart containerd`
6. Verify status again: `sudo systemctl status containerd`~~

###### kube-controller-manager

1. Execute: `sudo vim /etc/kubernetes/manifests/kube-controller-manager.yaml`
2. Add the following lines `- --cloud-provider=aws` and `- --cluster-name=mycluster` to the section: `spec.containers.command:`

(picX)

###### AWS Cloud Controller Manager (CCM)

When deploying AWS Cloud Controller Manager (CCM) as a DaemonSet in the cluster, it will be responsible for creating Load Balancers, managing nodes, etc. The aws-cloud-controller-manager Pod is the one that uses the credentials of the instance's IAM Role and manages everything.


2. Install (CNI) network plugin (Flannel). Without CNI the Pods of CoreDNS and other components can't initiate: `kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml`
3. Install Helm: `sudo snap install helm --classic`
4. Allow inbound rule from address `172.31.21.249` on port `6443` to allow the installation from Helm 
5. Install AWS CCM:

```
helm repo add aws-cloud-controller-manager https://kubernetes.github.io/cloud-provider-aws
helm repo update
helm install aws-ccm aws-cloud-controller-manager/aws-cloud-controller-manager
```

~~1. Initiate your cluster with kubeadm: `kubeadm init --pod-network-cidr=10.244.0.0/16`~~

1. Verify that the aws-cloud-controller-manager Pod is running on kube-system: `kubectl get pods -n kube-system`
2. You should get back something like `aws-cloud-controller-manager-xxxxx`. Check its logs: `kubectl logs -n kube-system aws-cloud-controller-manager-xxxxx`.
3. Verify whether the Pod is hung for other motive: `kubectl describe pod -n kube-system aws-cloud-controller-manager-xxxxx`
4. Execute: `kubectl get pods -n kube-system`.

If you get back one Pod categorized as `CrashLoopBackOff` it means that the container is being recursively initialized due to an internal error. This error usually is that the AWS CCM can't access to the AWS API (lacks of IAM Role). For a single-node cluster (control plane + worker on the same instance), Flannel must be allowed (and any essential DaemonSets) to run on the same node. Remove the taint: `kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule-` With this, Flannel will programm on the control-plane node and will create `/run/flannel/subnet.env` for the network to work (`kubernetes.io/cluster/<CLUSTER_NAME>=owned`).

Second step,  add `tags` to your AWS resources (VPC, subnets, instances, etc). The CCM will see this tag and recognize the nodes/permissions that belong to that cluster. If you want your <CLUSTER_NAME> to be `mycluster`, find the tags for each AWS resource you created and add the following values in EC2 instances -> Select instance -> Tags -> Add:
```
Key = kubernetes.io/cluster/mycluster
Value = owned
```
Do the same for VPC -> Subnets -> Select subnet -> Add. If the LB must have public IP the subnet must be public as well. To make it public the subnet must have an Internet Gateway associated to the route. Go to `Route tables`, add `0.0.0.0/0` with target `<Internet_Gateway>`. To find the internet gateway go to VPC dashboard -> Virtual Private Cloud -> Internet gateways. Copy the internet gateway ID.
With this, Flannel will bring up the network in the master node (because it is a cluster of one node) and AWS CCM will find the “ClusterID”. This combination allows the CCM to identify which EC2/ELB resources are bound to the Kubernetes cluster.

Usually with default settings Kubernetes node is not able to get information from the AWS Instance Metadata Service (IMDS) when doing curl. Without that access to the metadata, the AWS Cloud Controller Manager cannot automatically discover the Region/Zone/AZ.
Go to AWS -> EC2 Instances -> Select instance -> Actions -> Modify instance metadata options (Make sure IMDS is enabled).

(picX)


Wait a few minutes and run: `curl http://169.254.169.254/latest/meta-data/placement/availability-zone` it must return your Region AZ. Open the daemonset `kubectl edit ds aws-cloud-controller-manager -n kube-system` and in `args:` section paste: `- --controllers=*,-route`. With the route controller disabled, K8s will not attempt to configure routes in the VPC.

Before moving to the next section:
1. Make sure the node and those subnets are in the same region.
2. Check the routing table of each subnet (must have internet gateway).
3. Add as inbound rule subnet IPs into the K8s server. For that:

   a. AWS -> EC2 -> Load Balancers -> Select LB -> In Description/Attributes you will see `subnets` -> Search that subnet-ID in (VPC -> Subnets) -> Copy the CIDR block (That is the subnet IP). Add as port <LB_NODEPORT>.

###### IAM Role and SGs

###### IAM Role

Now, go through your AWS website. Access:

AWS -> EC2 (kubernetes-server) -> Security Groups:
Allow inbound rule: Type (HTTP), Port (80), Source (Your IP/Anywhere)

The EC2 instance that uses kubernetes must be asociated with an IAM rol with permissions to: Create, modify, eliminate LBs, obtain subnets and security groups information and associate an LB to the instances. To add these permissions:

IAM console in AWS -> Policies -> Create Policy -> Select JSON and paste the content from permissions.json -> Policy name: K8sELBAccessPolicy -> Create Policy.

Now access IAM console in AWS -> Roles -> Create (Trusted entity type: AWS Service, Service or Use case: EC2) -> Select your K8's policy:

![alt text](pics/pic28.png)

Set as role name: K8s-EC2-ELB-Role -> Create Role.
Go to EC2 instances -> Select kubernetes-server -> Actions -> Security -> Modify IAM rol -> Assign the role created with `permission.json`. -> Reboot the instance.

This way, when K8s (`kube-controller-manager`) makes calls to the AWS API to create the ELB, it will automatically use the credentials of that IAM Role attached to the instance.

###### Explanation why the following Allow Actions:

1. `"ec2:Describe*"`: Kubernetes needs to discover resources like subnets, VPCs, and security groups to attach the ELB correctly.
2. `"ec2:CreateTags"`: Kubernetes tags resources like ELBs, subnets, and security groups so it can later identify and manage them.
3. `"ec2:AuthorizeSecurityGroupIngress"`: When the ELB is created, Kubernetes needs to allow traffic into the pods by modifying the security group.
4. `"elasticloadbalancing:*"`: This is the core of what allows Kubernetes to create and manage the ELB.
5. `"iam:ListServerCertificates"`: When service uses HTTPS, Kubernetes needs to retrieve certificates to assign them to the load balancer.
6. `"iam:GetServerCertificate"`: To inspect a specific certificate when setting up HTTPS listeners.
7. `"iam:ListRolePolicies"` and `"iam:GetRolePolicy"`: Required by Kubernetes controllers to check IAM role capabilities

###### SGs

After setting the Security Groups table at the beginning, for AWS to be able to assign an instance ID to the LB a patch in `spec.providerID` 
route from the node is required. Run:
```
kubectl patch node <NODE_NAME> \
  -p '{"spec":{"providerID":"aws:///<AZ_REGION>/<INSTANCE_ID>"}}'
```
This way K8s will know which EC2 instance corresponds to the node and will register to it the LB. Execute: `kubectl describe node <NODE_NAME> | grep ProviderID`. A return as follows is expected: `ProviderID:  aws:///<AZ_REGION>/<INSTANCE_ID>`.

Access the LB -> Target instances -> Add target instance (K8s server).

To deploy the complete service run:
```
kubectl apply -f Deployment.yml
kubectl apply -f Service.yml
```
First command creates the Deployment (Pods), second command creates the Service (AWS-CCM will create the ELB automatically)

###### Service.yml

The easiest way to create an ELB manually is to define a `Service.yaml` with `type: LoadBalancer`. When executing `kubectl apply -f Service.yml` K8s will create in AWS the LB, a target group, listener, security rules, etc. After that, verify that the LoadBalancer is created: `kubectl get svc`.

After 2 minutes execute: `kubectl get svc tetris-service`

###### Deployment.yml

Deployment is in charge of running the container in the cluster. Execute: `kubectl apply -f Deployment.yml`.

After setting the Service and Deployment, targets must be registered. If the LB Target Group is still in the “unhealthy” state and “Registered targets (0)” or “unhealthy” when inspecting, it means that the Load Balancer is not able to successfully connect to the node on the corresponding health check port or NodePort. Define como “health check port” los puertos `80` o `<LB_NODEPORT>`.

Once the Service has launched the ELB and the application is running in the Pods get the ELB DNS with `kubectl get svc tetris-service`.

### Minikube (Install both in Ansible and Kubernetes server)

Minikube is a lightweight Kubernetes tool that runs a single-node Kubernetes cluster locally on your machine. It is mainly used for development, testing, and learning Kubernetes without needing a full multi-node setup. For Minikube installation I used the following [tutorial post](https://www.digitalocean.com/community/tutorials/how-to-use-minikube-for-local-kubernetes-development-and-testing)

1. Activate root user: `sudo su`
2. Download and install Minikube binary for Ubuntu: `curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64`
3. Move the Minikube binary to `/usr/local/bin/` and make it executable: `install minikube-linux-amd64 /usr/local/bin/minikube`
4. Start Minikube with a compatible driver (using Docker): `minikube start --driver=docker`
5. Check all running pods in all namespaces: `kubectl get pods -A`

If kubectl is not recognised:

#### kubectl

kubectl is the command-line tool for interacting with Kubernetes clusters. It allows you to deploy applications, inspect resources, manage cluster components, and troubleshoot issues.

1. Update package lists and install transport support for HTTPS repositories: `apt-get update && apt-get install -y apt-transport-https`
3. Add Kubernetes GPG Key:
```
mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | tee /etc/apt/keyrings/kubernetes-apt-keyring.asc > /dev/null
```
4. Add Kubernetes Repository: `echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.asc] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list`
5. Update and Install kubectl:
```
sudo apt update
sudo apt install -y kubectl
```
6. Exit root mode: `exit`
7. Verify kubectl Installation: `kubectl version --client`
8. Add your user to the Docker group: `sudo usermod -aG docker $USER`
9. Apply the new group permissions: newgrp docker
10. Start Minikube: `minikube start --driver=docker`
11. Check if Kubernetes is working: `kubectl get pods -A`

![alt text](pics/pic11.png)

# CI/CD

## Github webhooks

GitHub Webhooks are automated HTTP callbacks that notify an external service (e.g. Jenkins, Slack, or a custom API) whenever specific events happen in a GitHub repository. It can be used to trigger CI/CD pipelines (our situation), send notifications or automate workflows.
To set it up, go to Jenkins Dashboard -> New Item (Name: jenkins-pipeline) -> For script introduce:

```
node {
    stage('Git checkout'){
        git 'https://github.com/3v401/DevOps.git'
    }
}
```

Save.

Now access to Github repository (DevOps) -> Settings -> Webhooks -> Add new Webhook:

1. Payload URL: http://<JENKINS_IP>:<PORT>/github-webhook/
2. Content type: application/json
3. Secret: To introduce the secret go to the jenkins-server and Dashboard -> Your user -> Security -> Add new token. Save the token and paste it into the Secret section.

![alt text](pics/pic12.png)

4. Click on: Update webhook

![alt text](pics/pic13.png)

Refresh the page after ping is sent. If it doesn't work (error appears). Very likely it is because the Jenkins server doesn't allow inbound access from Github webhooks. For that:

Open new terminal and run: `curl -s https://api.github.com/meta | jq -r '.hooks[]'`

![alt text](pics/pic14.png)

This way you will get the list of IP addresses from GitHub to allow inbound rules.

![alt text](pics/pic15.png)

Go to Webhooks (the one with error) -> Edit -> Recent Deliveries -> Redelivery. You will get the ping correctly.
Open the Dockerfile in our project and add a new port (e.g., 22). Save, commit and push. You will observe in the Jenkins Dashboard the following:

![alt text](pics/pic16.png)

(picx) show Jenkins dashboard of the updated version with the webhook

## Jenkins connection to Ansible

Set Global (unrestricted) credentials:

Access to: Dashboard -> Manage Jenkins -> Credentials -> System -> Global credentials (unrestricted) -> Add credentials

Kind: SSH Username with private key, Scope: Global, ID: ansible_demo, Description: ansible_demo, Username: <ANSIBLE_USERNAME>, Private Key: Enter directly (enter your private key from your pem file).

Once finished, you will get the following credentials list:

![alt text](pics/pic16.png)

Now access to a created `jenkins-pipeline` via: Dashboard -> jenkins-pipeline -> Pipeline Syntax. Sample Step: sshagent: SSH Agent, select 'ubuntu (ansible_demo)', then select 'Generate Pipeline Script'. It will return:
```
sshagent(['ansible_demo']) {
    // some block
}
```

Save this snippet in a txt file.

### Communication Jenkins <-> Ansible

To allow communication to Ansible, access: Ansible EC2 -> Security Groups -> Edit Inbound rules:
1.  All traffic, source "My IP", Description: My IP traffic
2.  SSH, source "Jenkins IP", Description: SSH connection Jenkins - Ansible.

### Sending content from Jenkins to Ansible

After establishing the connection, generate the following pipeline content:

```
node {
    stage('Git checkout'){
        git 'https://github.com/3v401/DevOps.git'
    }
    stage('Sending Jenkins content to Ansible server over ssh'){
        sshagent(['ansible_demo']){
            sh 'ssh -o StrictHostKeyChecking=no <ANSIBLE_USERNAME>@<ANSIBLE_PUBLIC_IP>'
            sh 'scp /var/lib/jenkins/workspace/jenkins-pipeline/Tetris-Game/* <ANSIBLE_USERNAME>@<ANSIBLE_PUBLIC_IP>:/home/<ANSIBLE_USERNAME>'
        }
    }
}
```

Click on apply, save and click on `build now`. Wait until you get feedback. You will get the following outcome:

![alt text](pics/pic17.png)

Jenkins prompts that the content has been sent correctly from Jenkins to Ansible. To check everything is setup, let's access the ansible terminal and verify its content:

![alt text](pics/pic18.png)

As expected, the content is also located in the Ansible server.


### Communication Ansible <-> DockerHub

#### Building

In the Jenkins pipeline add the following snippet:

```
stage('Docker build image'){
    sshagent(['ansible_demo'])}
        sh 'ssh -o StrictHostKeyChecking=no <ANSIBLE_USERNAME>@<ANSIBLE_PUBLIC_IP> cd /home/<ANSIBLE_USERNAME>/'
        sh 'ssh -o StrictHostKeyChecking=no <ANSIBLE_USERNAME>@<ANSIBLE_PUBLIC_IP> docker imge build -t $JOB_NAME:v1.$BUILD_ID .'
    }
}
```

1. Connect to your Jenkins server, check the files: `ls -la /var/lib/jenkins/workspace/jenkins-pipeline`
2. Connect to your Ansible server, check the files: `ls -la ~`
3. In your Ansible server run: `sudo docker image ls`

![alt text](pics/pic19.png)

Congratulations, your Docker image has been built!

#### Tagging

Now let's tag it for later pushing it to the DockerHub. Add the following snippet to the previous jenkins-pipeline:

```
stage('Docker image tagging'){
    sshagent(['ansible_demo']){
        sh 'ssh -o StrictHostKeyChecking=no <ANSIBLE_USERNAME>@<ANSIBLE_PUBLIC_IP> cd /home/<USERNAME>/'
        sh 'ssh -o StrictHostKeyChecking=no <ANSIBLE_USERNAME>@<ANSIBLE_PUBLIC_IP> docker image tag $JOB_NAME:v1.$BUILD_ID <DOCKER_USERNAME>/$JOB_NAME:v1.$BUILD_ID '
        sh 'ssh -o StrictHostKeyChecking=no <ANSIBLE_USERNAME>@<ANSIBLE_PUBLIC_IP> docker image tag $JOB_NAME:v1.$BUILD_ID <DOCKER_USERNAME>/$JOB_NAME:latest '
    }
}
```

Run the pipeline, you will get the following outcomes in the jenkins-pipeline and Ansible server:

![alt text](pics/pic20.png)

![alt text](pics/pic21.png)

#### Pushing to DockerHub

Access: Dashboard -> Manage Jenkins -> Credentials -> System -> Global credentials (unrestricted)

New credentials. Kind (Secret text), Scope (Global), Secret (your DockerHub password), ID (`dockerhub_pass`), Description (`dockerhub_pass`), Create.

Access: Dashboard -> jenkins-pipeline -> Pipeline Syntax

Sample Step (withCredentials: Bind credentials to variables), Variable (`dockerhub_pass`), Credentials (`dockerhub_pass`), Generate Pipeline Script.

Add the following snippet to the previous jenkins-pipeline:

```
    stage('Push Docker image to DockerHub'){
        sshagent(['ansible_demo']){
            withCredentials([string(credentialsId: 'dockerhub_pass', variable: 'dockerhub_pass')]) {
                    sh 'ssh -o StrictHostKeyChecking=no <ANSIBLE_USERNAME>@<ANSIBLE_PUBLIC_IP> docker login -u <DOCKERHUB_USERNAME> -p ${dockerhub_pass} '
                    sh 'ssh -o StrictHostKeyChecking=no <ANSIBLE_USERNAME>@<ANSIBLE_PUBLIC_IP> docker image push <DOCKERHUB_USERNAME>/$JOB_NAME:v1.$BUILD_ID '
                    sh 'ssh -o StrictHostKeyChecking=no <ANSIBLE_USERNAME>@<ANSIBLE_PUBLIC_IP> docker image push <DOCKERHUB_USERNAME>/$JOB_NAME:latest '
            }
        }
    }
```

Apply and Save. Click 'Build Now'. You must get the following outcome into the jenkins-pipeline:

Access: Dashboard -> Manage Jenkins -> Credentials -> System -> Global credentials (unrestricted)

![alt text](pics/pic22.png)

and into your DockerHub account:

![alt text](pics/pic23.png)

Congratulations! You uploaded your Docker image into DockerHub via Jenkins and Ansible!

### Communication Jenkins <-> Ansible <-> Kubernetes

Remember to allow inbound/outbound connections between Jenkins <-> Ansible <-> Kubernetes
Generate a pass key as we did in Ansible but for Kubernetes.

Acess: Dashboard -> Manage Jenkins -> Credentials -> SYstem -> Global credentials (unrestricted) -> Add Credentials

Kind (SSH Username with private key), ID (kubernetes_server), Description (kubernetes_server), Username (<KUBERNETES_USERNAME>), Private Key (Enter directly Key, your pem private key).

Add the following snippet to the jenkins-pipeline:

```
    stage('Copy files from Ansible to Kubernetes server'){
        sshagent(['kubernetes_server']){
            sh 'ssh -o StrictHostKeyChecking=no <KUBERNETES_USERNAME>@<KUBERNETES_PRIVATE_IP> '
            sh 'scp /var/lib/jenkins/workspace/jenkins-pipeline/Tetris-Game/* <KUBERNETES_USERNAME>@<KUBERNETES_PRIVATE_IP>:/home/<KUBERNETES_USERNAME>/ '
        }
    }
    stage('Kubernetes Deployment using Ansible'){
        sshagent(['kubernetes_server']){
            sh 'ssh -o StrictHostKeyChecking=no <ANSIBLE_USERNAME>@<ANSIBLE_PUBLIC_IP> cd /home/<ANSIBLE_USERNAME>/ '
            sh 'ssh -o StrictHostKeyChecking=no <ANSIBLE_USERNAME>@<ANSIBLE_PUBLIC_IP> ansible -m ping node '
            sh 'ssh -o StrictHostKeyChecking=no <ANSIBLE_USERNAME>@<ANSIBLE_PUBLIC_IP> ansible-playbook ansible.yml '
        }
    }
```

1. `ansible -m ping node`: Is used to test SSH connectivity between the Ansible control server and the hosts defined under the group node (Kubernetes).
2. `ansible-playbook ansible.yml`: Runs the ansible.yml playbook that contains tasks to deploy and configure resources on the Kubernetes server.

### SSH connection Ansible <-> Kubernetes server

###### Access the Kubernetes Server

1. Activate root user: `sudo su`
2. Set new password for sudo user: `passwd root`
3. Go to: `vim /etc/ssh/sshd_config`. Find and set `PermitRootLogin prohibit-password`, `PasswordAuthentication no` and `PubkeyAuthentication yes`.
4. Restart the ssh2 service: `systemctl restart ssh`
5. Check your communication Kubernetes -> Ansible: `ping <PRIVATE_IP_ANSIBLE>`

###### Access the Ansible Server

1. Activate root user: `sudo su`
2. Generate a key: `ssh-keygen -t rsa -b 4096 -C "ansible-to-k8s"`. Your public key will be located at: `/root/.ssh/id_rsa.pub`
3. Check your communication Ansible -> Kubernetes: `ping <PRIVATE_IP_KUBERNETES>`
4. Copy your public rsa key: `cat /root/.ssh/id_rsa.pub`

###### Access the Kubernetes Server

1. Create folder: `sudo mkdir -p /root/.ssh`
2. Open file: `sudo vim /root/.ssh/authorized_keys` and paste there the content of the Ansible server `id_rsa.pub` public key.
3. Restart ssh: `systemctl restart ssh`

###### Access the Ansible Server

1. Execute: `ssh root@<PRIVATE_IP_KUBERNETES>`

![alt text](pics/pic24.png)

Bingo! You are in kubernetes server from ansible server as root.

Now, exit your connection and from the default user in your Ansible terminal run:

1. Access the file: vim /etc/ansible/hosts
2. Write at the bottom:
```
[node]
<KUBERNETES_PRIVATE_IP>
```
3. Test the connection to the `node` group: `ansible -m ping node`
You will get the following outcome:

![alt text](pics/pic25.png)

###### Access the Jenkins Server

Now an ssh key must be generated for Jenkins -> Kubernetes. Let's repeat the process.

1. Activate root user: `sudo su`
2. Generate a key: `ssh-keygen -t rsa -b 4096 -C "jenkins-to-k8s"`. Your public key will be located at: `/root/.ssh/id_rsa.pub`
3. To allow communication Jenkins <-> Kubernetes create an inbound rule in both servers setting an allow ICMP IPv4 in each server with their destination <KUBERNETES/JENKINS_PRIVATE_IP> respectivelly. ICMP is the type inbound rule for ping messages.
4. Check your communication Jenkins -> Kubernetes: `ping <PRIVATE_IP_KUBERNETES>`
5. Copy your public rsa key: `cat /root/.ssh/id_rsa.pub`

###### Access the Kubernetes Server

1. Then as a sudo user, open file: `vim /root/.ssh/authorized_keys` and paste there the content of the Jenkins server `id_rsa.pub` public key.
2. Restart ssh: `systemctl restart ssh`
3. If you turned your instance off during this lab. Set up again minikube: `minikube start`
4. You will get the following outcome in the Kubernetes terminal:

![alt text](pics/pic26.png)

###### Access the Jenkins Server

Before running any command, access AWS, set inbound rules in both Jenkins and Kubernetes. Allow SSH connection from Kubernetes and Jenkins internal IPv4 addresses.

1. Run the following command from Jenkins terminal: `ssh root@<KUBERNETES_PRIVATE_IP>`

![alt text](pics/pic27.png)

Bingo! You are connected from Jenkins to Kubernetes server.

Now enter the Jenkins browser and run the pipeline. You must get the following outcome:
