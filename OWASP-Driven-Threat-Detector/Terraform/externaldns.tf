resource "null_resource" "wait_for_eks" {
  provisioner "local-exec" {
    command = <<EOT
      echo "Waiting for EKS API to respond..."
      until kubectl version --request-timeout='5s'; do
        echo "Still waiting for EKS... "
        sleep 10
      done
      echo "EKS is ready"
    EOT
  }

  depends_on = [null_resource.update_kubeconfig]
}

resource "null_resource" "wait_for_kube_api" {

  provisioner "local-exec" {
    command = "kubectl get nodes --context arn:aws:eks:eu-north-1:039612864283:cluster/${module.eks.cluster_name}"
  }

  depends_on = [
    module.eks,
    null_resource.update_kubeconfig
  ]
}

resource "helm_release" "externaldns" {
    provider = helm.eks
    name            = "external-dns"
    namespace       = "default"
    repository = "https://kubernetes-sigs.github.io/external-dns"
    chart      = "external-dns"
    version = "1.16.1"
    
    set {
        name = "provider"
        value = "cloudflare"
    }

    set {
        name = "cloudflare.apiToken"
        value = var.CLOUDFLARE_TOKEN
    }

    set {
        name = "domainFilters[0]"
        value = var.MY_DOMAIN
    }

    set {
        name = "policy"
        value = "sync"
    }

    set {
        name = "registry"
        value = "txt"
    }

    set {
        name = "txtOwnerId"
        value = "threatgpt"
    }

    # Ensure this provider waits for the EKS cluster and kubeconfig update
    depends_on = [
      module.eks,
      null_resource.update_kubeconfig,
      null_resource.wait_for_eks,
      null_resource.wait_for_kube_api
    ]

}