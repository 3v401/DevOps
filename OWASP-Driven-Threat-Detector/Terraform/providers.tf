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

# Define the primary Kubernetes provider for direct K8s resources (e.g., kubernetes_service_account)
# provider "kubernetes" {
#   alias       = "null"
#   # This provider will be used by kubernetes_service_account and other direct k8s resources
#   host                   = data.aws_eks_cluster.cluster.endpoint
#   cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
#   token                  = data.aws_eks_cluster_auth.cluster.token

#   exec {
#     api_version = "client.authentication.k8s.io/v1beta1"
#     command     = "aws"
#     args        = ["eks", "get-token", "--cluster-name", data.aws_eks_cluster.cluster.name, "--region", "eu-north-1", "--profile", "developer"]
#   }
# }

# Second kubernetes (not for module eks)
provider "kubernetes" {
  alias = "eks"
  # No alias here means it's the default Kubernetes provider.
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", data.aws_eks_cluster.cluster.name, "--region", "eu-north-1", "--profile", "developer"]
  }
}

provider "helm" {
  alias       = "eks"
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = "arn:aws:eks:eu-north-1:039612864283:cluster/API_EKS_ThreatGPT"
  }
}

provider "kubernetes" {
  alias       = "null"
  host                   = "https://0.0.0.0"
  cluster_ca_certificate = ""
  token                  = ""
}