# IAM (Setup) Roles and Policies: Securely allow your EC2 instances and services to interact with AWS resources

# IAM Role:
# All EC2 instances must have:

resource "aws_iam_role" "my_ec2_instance_role" {
  name = "ec2_instance_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "my_ec2_instance_role"
  }
}

# IAM Policy:

resource "aws_iam_policy" "my_ec2_basic_policy" {
  name        = "my_ec2_policy"
  path        = "/"
  description = "my_ec2_policy_description"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_policy_attach" {
  role       = aws_iam_role.my_ec2_instance_role.name
  policy_arn = aws_iam_policy.my_ec2_basic_policy.arn
}

resource "aws_iam_instance_profile" "my_ec2_instance_profile" {
  # This instance profile will be used by Jenkins, Monitoring, Scanner, Builder
    # Jenkins: Needs S3, logs, Terraform CLI, etc.
    # Monitoring: Sends metrics/logs to CloudWatch
    # Scanner: 	Downloads CVE data, uploads reports
    # Builder: Sends Docker Image to DockerHub
  name = "my_ec2_instance_profile_description"
  role = aws_iam_role.my_ec2_instance_role.name
}

# EKS

resource "aws_iam_role" "eks-cluster" {
  name = "eks-cluster-example"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Effect = "Allow"
        Principal = {
          Service = [
            "ec2.amazonaws.com",
            "eks.amazonaws.com"
          ]
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks-cluster.name
}

# Node group
# Node groups must use a separate IAM role from the EKS cluster
resource "aws_iam_role" "eks_node_group_iam_role" {
  name = "eks-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })  
}

resource "aws_iam_role_policy_attachment" "eks_worker_node" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  ])

  policy_arn = each.value
  role       = aws_iam_role.eks_node_group_iam_role.name
}

# ALB Controller

resource "aws_iam_role" "ALB_controller" {
  name = "EKS-ALB_controller"

  # Let K8s ServiceAccount assume this role via IAM Roles for Service Account (IRSA)
  # This role is assumed by a ServiceAccount, not EC2
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Condition = {
          # Makes sure only aws-load-balancer-controller in kube-system can assume it
          # Links to a specific service account in a namespace
          StringEquals = {
            "${replace(module.eks.oidc_provider_arn, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          }
        }
      },
    ]
  })

  tags = {
    tag-key = "ALB IAM role"
  }
}

resource "aws_iam_policy_attachment" "ALB_controller_policy_attachment" {
  name       = "ALB controller policy attachment"
  roles      = [aws_iam_role.ALB_controller.name]
  policy_arn = aws_iam_policy.alb_controller_policy.arn
}

# Downloaded the following policy in Terraform path:
# curl -o iam_policy_alb_controller.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
# It creates the IAM policy required to let the AWS LB Controller manage ALBs in the EKS cluster

resource "aws_iam_policy" "alb_controller_policy" {
  name            = "AWSLoadBalancerControllerIAMPolicy"
  policy          = file("${path.module}/iam_policy_alb_controller.json")
}

resource "aws_iam_policy_attachment" "alb_controller_attach" {
  name            = "ALBControllerPolicyAttachment"
  roles           = [aws_iam_role.ALB_controller.name]
  policy_arn      = aws_iam_policy.alb_controller_policy.arn
}

# OIDC (OpenID Connect) provider:

# Define OpenID Connect (oidc) provider for IAM Roles for Service Account (IRSA)
# This enables IAM Roles for Kubernetes Service Accounts (IRSA) which the AWS Load Balancer
# Controller requires to authenticate with AWS
# resource "aws_iam_openid_connect_provider" "oidc" {
#   url = module.eks.cluster_oidc_issuer_url

#   client_id_list = ["sts.amazonaws.com"]
  # AWS root CA's hash (default)
#   thumbprint_list =["9e99a48a9960b14926bb7f3b02e22da0ecd6f4c9"]
# }

# resource "kubernetes_service_account" "alb_sa" {
  # This links the K8s service account to the IAM role using the annotation "eks.amazonaws.com/role-arn"
#   metadata {
#     name          = "aws-load-balancer-controller"
#     namespace     = "kube-system"
#     annotations   = {
#       "eks.amazonaws.com/role-arn" = aws_iam_role.ALB_controller.arn
#     }
#   }

#   depends_on = [
    # aws_eks_cluster.API_EKS,
    # aws_eks_node_group.private_nodes,
#     module.eks
#   ]
# }

# ------------------------------------------------------------------------------------------------------------ EKS IAM ROLE BUILDER

resource "aws_iam_role" "builder_eks_role" {

  name = "builder-eks-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster" {
  # Attach AmazonEKSClusterPolicy to allow Builder to manage EKS clusters
  policy_arn          = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role                = aws_iam_role.builder_eks_role.name
}

resource "aws_iam_role_policy_attachment" "eks_worker" {
  # Attach AmazonEKSWorkerNodePolicy to allow Builder to interact with EKS worker nodes
  policy_arn          = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role                = aws_iam_role.builder_eks_role.name
}

resource "aws_iam_role_policy_attachment" "ecr_access" {
  # Attach ECR read-only permissions to allow pulling Docker images (if needed in future project versions)
  policy_arn          = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role                = aws_iam_role.builder_eks_role.name
}

resource "aws_iam_role_policy_attachment" "s3_access" {
  # Attach full access to S3 for uploading/downloading
  policy_arn          = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  role                = aws_iam_role.builder_eks_role.name
}

resource "aws_iam_instance_profile" "builder_profile" {
  # Create instance profile that wraps the IAM role policies
  name                = "builder-eks-profile"
  role                = aws_iam_role.builder_eks_role.name
}

# ------------------------------------------------------------------------------------------------------------DEVELOPER USER IAM POLICY
# This IAM policy must be attached to the IAM user (whoever runs 'terraform apply')
# to prevent permission errors. It grants the necessary EKS and IAM access.
# 'developer' is the user who deploys infrastructure with terraform

resource "aws_iam_policy" "developer_eks_access" {
  name          = "DeveloperEKSAccess"
  description   = "Grant EKS + IAM PassRole access"
  policy        = file("${path.module}/developer_eks_policy.json")
}

resource "aws_iam_user_policy_attachment" "attach_developer_policy" {
  user          = "developer"
  policy_arn    = aws_iam_policy.developer_eks_access.arn
}


# ------------------------------------------------------------------------------------------------------------ PODS

# Required to make Terraform wait 60 seconds for EKS internal services to be ready 
resource "null_resource" "wait_for_cluster" {
  provisioner "local-exec" {
    command = "sleep 60"
  }

  depends_on = [module.eks]
}

# Link the ALB controller pod to its IAM role
resource "kubernetes_service_account" "alb_sevice_account_pods" {
  provider = kubernetes.eks
  metadata {
    name              = "aws-load-balancer-controller"
    namespace         = "kube-system"
    annotations       = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.ALB_controller.arn
    }
  }

  depends_on = [
    # This dependency ensures the service account is created only after
    # the EKS cluster is ready and its API is responsive.
    null_resource.wait_for_cluster,
    null_resource.update_kubeconfig, # Ensures kubeconfig is updated
    null_resource.wait_for_eks       # Ensures EKS API is reachable
  ]
}

resource "null_resource" "print_kubeconfig" {
  # Debug print of the current kubeconfig context
  provisioner "local-exec" {
    command = "kubectl config current-context && kubectl get nodes"
  }

  depends_on = [null_resource.update_kubeconfig]
}