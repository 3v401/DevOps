# ----------------------------------------------------------------
# iam.tf
# ----------------------------------------------------------------

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

# ---------------------------------------------------------------- ECR access for scanner ec2

resource "aws_iam_policy" "ecr_pull_access" {
  name        = "ECRPullAccess"
  description = "Allow pulling Docker images from ECR"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "scanner_role" {
  name = "scanner-ec2-role"

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

resource "aws_iam_role_policy_attachment" "scanner_ecr_access" {
  role       = aws_iam_role.scanner_role.name
  policy_arn = aws_iam_policy.ecr_pull_access.arn
}

resource "aws_iam_instance_profile" "scanner_instance_profile" {
  name = "scanner-ec2-instance-profile"
  role = aws_iam_role.scanner_role.name
}

# ---------------------------------------------------------------- Control Plane iam role EKS

resource "aws_iam_role" "eks" {
  name = "${local.env}-${local.eks_name}-eks-cluster"

  assume_role_policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "sts:AssumeRole",
            "Principal": {
                "Service": "eks.amazonaws.com"
            }
        }
    ]
}
POLICY
}

# Attach AmazonEKSClusterPolicy to the IAM role
resource "aws_iam_role_policy_attachment" "eks" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks.name
}

# ---------------------------------------------------------------- K8s Node iam role Group

resource "aws_iam_role" "nodes" {
    name = "${local.env}-${local.eks_name}-eks-nodes"
    assume_role_policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "sts:AssumeRole",
            "Principal": {
                "Service": "ec2.amazonaws.com"
            }
        }
    ]
}
POLICY
}

# ---------------------------------------------------------------- Attach IAM Policies to the Nodes

resource "aws_iam_role_policy_attachment" "amazon_eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.nodes.name
}

resource "aws_iam_role_policy_attachment" "amazon_eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.nodes.name
}

resource "aws_iam_role_policy_attachment" "amazon_ec2_container_registry_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.nodes.name
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

# resource "aws_iam_policy_attachment" "ALB_controller_policy_attachment" {
#   name       = "ALB controller policy attachment"
#   roles      = [aws_iam_role.ALB_controller.name]
#   policy_arn = aws_iam_policy.alb_controller_policy.arn
# }

# Downloaded the following policy in Terraform path:
# curl -o iam_policy_alb_controller.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
# It creates the IAM policy required to let the AWS LB Controller manage ALBs in the EKS cluster

resource "aws_iam_policy" "alb_controller_policy" {
  name            = "AWSLoadBalancerControllerIAMPolicy"
  policy          = file("${path.module}/iam_policy_alb_controller.json")
}

# resource "aws_iam_policy_attachment" "alb_controller_attach" {
#   name            = "ALBControllerPolicyAttachment"
#   roles           = [aws_iam_role.ALB_controller.name]
#   policy_arn      = aws_iam_policy.alb_controller_policy.arn
# }

# ---------------------------------------------------------------- Builder EC2 IAM role

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

# Needed for 'kubectl apply'
resource "aws_iam_role_policy_attachment" "eks_worker" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.builder_eks_role.name
}

# Required to push Docker images to ECR
resource "aws_iam_role_policy_attachment" "ecr_power_user" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
  role       = aws_iam_role.builder_eks_role.name
}

# Optional: If your app stores logs or reports in S3
resource "aws_iam_role_policy_attachment" "s3_access" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  role       = aws_iam_role.builder_eks_role.name
}

# Access to the eks cluster
resource "aws_iam_role_policy_attachment" "eks_cluster_access" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.builder_eks_role.name
}

# EC2 instance profile
resource "aws_iam_instance_profile" "builder_profile" {
  name = "builder-eks-profile"
  role = aws_iam_role.builder_eks_role.name
}