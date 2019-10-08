
resource "local_file" "kubeconfig" {
  content  = local.kubeconfig
  filename = "${path.module}/.kubeconfig"
}


locals {
  cni_cidr_subnet = cidrsubnet(
    aws_vpc.this.cidr_block,
    ceil(log(length(var.subnets), 2)),
    index(var.subnets, "cni")
  )
}


resource "null_resource" "cni_genie" {
  count = var.cni_genie_enabled ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOD
      export KUBECONFIG="${local_file.kubeconfig.filename}"

      kubectl delete daemonset \
        --namespace kube-system \
        --selector=k8s-app=aws-node

      kubectl apply --filename="https://raw.githubusercontent.com/cni-genie/CNI-Genie/master/conf/1.8/genie-plugin.yaml"
    EOD
  }
}


resource "null_resource" "cni_calico" {
  count = contains(var.cni_genie_networks, "calico") ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOD
      export KUBECONFIG="${local_file.kubeconfig.filename}"
      kubectl apply --filename="https://docs.projectcalico.org/v3.9/manifests/calico.yaml"
    EOD
  }

  depends_on = [
    null_resource.cni_genie
  ]
}


resource "null_resource" "cni_weave" {
  count = contains(var.cni_genie_networks, "weave") ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOD
      export KUBECONFIG="${local_file.kubeconfig.filename}"
      kubectl apply --filename="https://cloud.weave.works/k8s/net?k8s-version=${aws_eks_cluster.this.version}&env.IPALLOC_RANGE=${local.cni_cidr_subnet}"
    EOD
  }

  depends_on = [
    null_resource.cni_genie
  ]
}


resource "null_resource" "calico_network_policy" {
  count = var.calico_network_policy_enabled ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOD
      export KUBECONFIG="${local_file.kubeconfig.filename}"
      kubectl apply -f "https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/release-1.5/config/v1.5/calico.yaml"
    EOD
  }

  depends_on = [
    null_resource.cni_genie
  ]
}
