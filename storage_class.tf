
resource "null_resource" "delete_original_gp2" {

  provisioner "local-exec" {
    command = <<-EOD
      export KUBECONFIG="${local_file.kubeconfig.filename}"
      kubectl delete storageclass gp2
    EOD
  }
}


# https://docs.aws.amazon.com/en_pv/AWSEC2/latest/UserGuide/EBSVolumeTypes.html
resource "kubernetes_storage_class" "gp2" {
  metadata {
    name = "gp2"

    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner = "kubernetes.io/aws-ebs"
  reclaim_policy      = "Delete"

  parameters = {
    type      = "gp2"
    encrypted = "true"
  }

  depends_on = [
    null_resource.delete_original_gp2
  ]
}
