# End-to-End DevSecOps Pipeline with Cloudflare, Terraform, and OWASP-Driven Threat Detection

(Project under development)

I created 5 instances:
Bastion, Jenkins, Monitoring, Scanner, API
Bastion and API are the only ones that have also a Public IP address
Must accept my IP address as inbound in the Bastion server
Bastion must have access to Jenkins, Monitoring, API and scanner


Goal of the project:

This project aims to automate and secure a cloud infrastructure using Terraform with AWS and Cloudflare embedding DevSecOps principleas incorporating threat detection, logging and observability.

Main skills for this project:
1. Infrastructure as Code (IaC) with Terraform
2. Cloudflare for DNS, DDoS and WAF protection as the **first line of defense**
3. AWS for hosting Cloud Capabilities (EC2, S3, EBS, IAM, VPC, CLoudWatch... etc)
4. Security Groups and IAM policies for least-privilege access
5. OWASP inspired threat monitoring via logs and alarms
6. Modular and secure deployment allowing CI/CD integration via Jenkins.

## Terraform

The terraform files are gathered in different files:

### providers.tf

Declares the AWS provider and sets the Terrraform version. Tells Terraform which profile to use (i.e., developer).

### vpc.tf

VPC architecture is foundational for security and segmentation. Internet Gateway is needed for public-facing services like Jenkins/API etc. NAT Gateway ensures secure outbound internet access from private services. The VPC structure is defined by:

1. **Two Public subnets**: For instances needing internet access (API EC2 and Bastion - admin entry point)
2. **Two Private subnets**: For internal-only services (Jenkins/OWASP/Monitoring servers). Keeps them invisible to the public. Associaed with private route table and NAT for secure internet egress.
3. **Internet Gateway**: Provides internet access to public subnets. Required for any resource that needs inbound/outbound internet traffic.
4. **NAT Gateway**: Crucial for Jenkins and OWASP scanner to download tools, plugins and updates securely without being publicly exposed. Allows private subnets to reach the internet without exposing instances (outbound only).
5. **Elastic IP**: For API instance. Assigns an static IP required for Cloudflare making it reachable via DNS.
6. **Route Tables**: Control traffic routing between subnets and external destinations. Splitting route tables gives you control over traffic flow.

     i. Public Route Table: Routes all traffic from public subnets to the internet via IGW
   
     ii. Private Route Table: Routes outbound traffic from private subnets to the internet through a NAT Gateway (with no inbound allowed)

Subnets placed in different AZs for high availability.

### instances.tf

1. **Bastion Instance**: Acts as a **secure entry point** for SSH aaccess to instances in private subnets. Installed only SSH. Protects private instances by requiring all access to fo through this gatekeeper.
2. **Jenkins Instance**: It is the CI/CD brain. Runs Jenkins, Git and Docker. Builds, tests and deploys. Deployed in a private subnet. Instance only reachable via Bastion. Uses IAM roles to access S3 and CloudWatch. Uses `userdata_jenkins.tpl` script to configure EC2 instance. Supports future Docker builds. Hardened with controlled firewall and isolated in private subnet.
3. **Monitoring Instance**: Runs observability stack (Prometheus: Metrics, Grafana: Dashboards). Deployed in private subnet. Aggregates logs, provides Dashboards and alerts to spot issues. 
4. **OWASP Instance**: Detects vulnerable libraries (OWASP Dependency-Check), scans web dynamically (OWASP ZAP), scanns container (Trivy). Placed in private subnet. Uses IAM Roles for permissions. Performs automated security scanning as part of the CI/CD pipeline. It finds vulnerabilities before production.
5. **API Instance**: Hosts te public-facing API. Installed Nginx, backend application and Certbot (for HTTPS). Deployed in a public subnet and exposed via Elastic IP for DNS Cloudflare. This is the core service clients interact with. Needs to be reachable via the internet -> in a public subnet. Protected by security groups and Cloudflare which handles WAF, DDoS and caching.

### security_groups.tf

Security Groups act as virtual firewalls. There are 4 Security groups in this project:

1. **First SG**: Public-Facing API server:

   i. Ingress Rule: Allowed traffic from anywhere (0.0.0.0/0) to ports 80 (HTTP) and 443 (HTTPS).

   ii. Egress Rule:  Allows all outbound traffic

2. **Second SG**: Jenkins and OWASP Scanner:

   i. Ingress Rule: Only allows SSH traffic from Bastion Host.

   ii. Egress: Full outbound internet access

3. **Third SG**: Monitoring Server (Prometheus, Grafana):

   i. Allows traffic on port 8080 (Prometheus default) from inside the VPC (10.0.0/16)

   ii. Egress: Full outbound internet access

4. **Fourth SG**: SSH Access from your IP (Bastion)

   i. Ingress: Allow SSH access only from your IP address (defined by `var.my_ip`)

   ii. Egress: Full outbound internet access

**SG Summary:**

| **Role**           | **Incoming Access Source**             | **Allowed Ports**             | **Public?** |
|--------------------|----------------------------------------|-------------------------------|-------------|
| **Bastion Host**   | Your IP only (`var.my_ip`)             | `22` (SSH)                    | Yes      |
| **API Server**     | Anywhere (`0.0.0.0/0`)                  | `80` (HTTP), `443` (HTTPS)    | Yes      |
| **Jenkins Server** | Bastion SG only                        | `22` (SSH)                    | No       |
| **OWASP Scanner**  | Bastion SG only                        | `22` (SSH)                    | No       |
| **Monitoring**     | Internal VPC only (`10.0.0.0/16`)      | `8080` (Prometheus/Grafana)   | No       |


### cloudwatch.tf

Monitors CPU utilization in this case. Trigger alerts if thresholds are exceeded (email will be sent). Collects and stores logs from EC2/apps. CloudWatch is key in DevSecOps because it enables early detection of threats and helps to automate responses or investigations.

There are three core CloudWatch capabilities:

1. **CloudWatch Alarm**: CPU Usage Threshold: If CPU usage >= 80% sends an alert to an SNS topic (sends email). This helps to detect unusual resource usage (DDoS/ Infinite loop/memory leak).
2. **CloudWatch Log Group**: App Logs Collection: Creates a log group to store application logs from the EC2 instances.
3. **Log Metric Filter**: Error Event Tracking: Scans logs in real time for events containing `ERROR`. This metric allows you to track error spikes/failed logins or security events via logs.

### iam.tf

This file defines IAM (Identity and Acess Management) setup for EC2 instances. It ensures that EC2 instances can interact with AWS services like CloudWatch and S3 in a controled way using least-privilege permissions. It prevents over-privileged access.

1. **IAM Role**: `my_ec2_instance_role`: Grants EC2 permission to assume this role, enabling AWS service access under a controlled identity.
2. **IAM Policy**: `my_ec2_basic_policy`: Permissions to CloudWatch Logs. Allows EC2 instances to push logs to CloudWatch. S3 Permissions (reading from and writing to S3 buckets).
3. **IAM Policy Role Attachment**: `ec2_policy_attach`: Links the policy to the role (without this, the role would have no permissions)
4. **IAM Instance Profile**: `my_ec2_instance_profile`: Binds the role to an instance profile. EC2 instances can only assume IAM roles via instance profiles.

### storage.tf

This file defines persistent storage resources. It defines an S3 bucket for centralized log storage and an EBS volume for Jenkins data to persist after `terraform destroy`.

### variables.tf

Declares inputs to avoid security flaws by isolating sensitive config variables/files. Makes Terraform code reusable and modular. The benefits of these variables are that it avoids hardcoding sensitive paths/IPs into infrastructure code, it supports multiple users/environments with different keys or alerts and integrates cleanly with `.tfvars` files or pipeline secrets.

### datasources.tf

Pulls data from existing AWS resources (AMI).