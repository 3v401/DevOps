# resource "aws_eks_cluster" "API_EKS" {
#   name = "API_EKS_ThreatGPT"

#   access_config {
#     authentication_mode = "API"
#   }

#   role_arn = aws_iam_role.eks-cluster.arn
#   version  = "1.31"

#   vpc_config {
#     subnet_ids = [
    # Subnets where EKS will deploy ENIs and communicate with nodes
#       aws_subnet.my_private_subnet_1.id,
#       aws_subnet.my_private_subnet_2.id,
#     ]
    # Allow access to K8s API from within VPC
#     endpoint_private_access = true
    # Allow access to K8s API from internet
#     endpoint_public_access = true
#     public_access_cidrs = [var.my_ip]
#   }

#   depends_on = [
    # Ensure policy is attached before cluster
#     aws_iam_role_policy_attachment.eks_AmazonEKSClusterPolicy,
#   ]
# }

# resource "aws_eks_node_group" "private_nodes" {
    # Connect this node group to the above cluster
#     cluster_name = aws_eks_cluster.API_EKS.name
#     node_group_name = "private-workers"
#     node_role_arn = aws_iam_role.eks_node_group_iam_role.arn
    
#     subnet_ids      = [
#         aws_subnet.my_private_subnet_1.id,
#         aws_subnet.my_private_subnet_2.id
#     ]

#     scaling_config {
        # # worker nodes
#         desired_size = 2
#         max_size     = 3
#         min_size     = 1
#     }

#     instance_types = ["t3.medium"]
# }

# --------------------------------------------------------------------------------------------aws-auth issue

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.21.0"

  cluster_name    = "API_EKS_ThreatGPT"
  cluster_version = "1.31"
  subnet_ids      = [aws_subnet.my_private_subnet_1.id, aws_subnet.my_private_subnet_2.id]
  vpc_id          = aws_vpc.my_main_vpc.id

  enable_irsa = true

  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = [var.my_ip]

  manage_aws_auth_configmap = true

  providers = {
    kubernetes = kubernetes.null
  #   # kubernetes = kubernetes
  }

  aws_auth_users = [
    {
      userarn  = "arn:aws:iam::039612864283:user/developer"
      username = "developer"
      groups   = ["system:masters"]
    }
  ]

  aws_auth_roles = [
    {
      rolearn  = aws_iam_role.eks_node_group_iam_role.arn
      username = "system:node:{{EC2PrivateDNSName}}"
      groups   = ["system:bootstrappers", "system:nodes"]
    }
  ]

  eks_managed_node_groups = {
    default = {
      desired_size = 2
      max_size     = 3
      min_size     = 1
      instance_types = ["t3.medium"]
      iam_role_arn = aws_iam_role.eks_node_group_iam_role.arn
    }
  }
}

# resource "kubernetes_config_map_v1_data" "aws_auth_config_map" {

#   metadata {
#     name      = "aws-auth"
#     namespace = "kube-system"
#   }

#   data = {
#     mapUsers = yamlencode([
#       {
#         userarn  = "arn:aws:iam::039612864283:user/developer"
#         username = "developer"
#         groups   = ["system:masters"]
#       }
#     ])
#     mapRoles = yamlencode([
#       {
#         rolearn  = aws_iam_role.eks_node_group_iam_role.arn
#         username = "system:node:{{EC2PrivateDNSName}}"
#         groups   = ["system:bootstrappers", "system:nodes"]
#       }
#     ])
#   }

#   depends_on = [
#     module.eks, # Ensure the EKS cluster itself is done creating
#     null_resource.update_kubeconfig,
#     null_resource.wait_for_eks,
#   ]
# }

resource "null_resource" "update_kubeconfig" {
  provisioner "local-exec" {
    command = "aws eks --region eu-north-1 update-kubeconfig --name ${module.eks.cluster_name} --profile developer"
  }

  depends_on = [module.eks]
}