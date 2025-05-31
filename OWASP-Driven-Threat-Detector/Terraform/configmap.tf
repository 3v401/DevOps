# resource "kubernetes_config_map" "aws_auth" {
#   metadata {
#     name      = "aws-auth"
#     namespace = "kube-system"
#   }

#   data = {
#     mapRoles = yamlencode([
#       {
#         rolearn  = aws_iam_role.eks_node_group_iam_role.arn
#         username = "system:node:{{EC2PrivateDNSName}}"
#         groups   = [
#           "system:bootstrappers",
#           "system:nodes"
#         ]
#       }
#     ])

#     mapUsers = yamlencode([
#       {
#         userarn  = "arn:aws:iam::039612864283:user/developer"
#         username = "admin"
#         groups   = ["system:masters"]
#       }
#     ])
#   }

#   depends_on = [
#     aws_eks_cluster.API_EKS,
#     module.eks
#     ]
# }