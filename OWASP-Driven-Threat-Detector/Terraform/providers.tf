terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  shared_config_files      = ["~/.aws/config"]
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = "developer"
}



# Configure K8s Provider
# provider "kubernetes" {
  # Connects to the EKS cluster endpoint (K8s API server)
#   host                  = data.aws_eks_cluster.cluster.endpoint
  # Ensures secure TLS communication with EKS cluster
#   cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  # Authenticate using temporary token
#   token                   = data.aws_eks_cluster_auth.cluster.token
# }

  provider "kubernetes" {
    alias                  = "null"
    host                   = "https://example.com"
    cluster_ca_certificate = ""
    token                  = ""
  }