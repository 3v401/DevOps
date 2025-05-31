# AMI:

data "aws_ami" "my_main_ubuntu_EC2_data" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-20250305"]
  }
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_name

  depends_on = [module.eks]
  # To not return error when terraform plan (it is expected)
}

# Auth to EKS (Fetch a token to authenticate to EKS)
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

data "template_file" "ingress_yaml" {
  template = file("${path.module}/../Builder-server/EKS/ingress.yaml.tpl")
  vars = {
    SUBNET_1 = aws_subnet.my_public_subnet_1.id
    SUBNET_2 = aws_subnet.my_public_subnet_2.id
  }
}

resource "local_file" "rendered_ingress" {
  # Writes the rendered file to disk. It overwrites the file every time 'terraform apply'
  content = data.template_file.ingress_yaml.rendered
  filename = "${path.module}/../Builder-server/EKS/ingress.yaml"
}