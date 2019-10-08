resource "kubernetes_service_account" "tiller" {
  count = var.helm_enabled ? 1 : 0

  metadata {
    name = "tiller"
    namespace = "kube-system"

    annotations = {
      managed_by_terraform = true
    }
  }
  depends_on = [
    kubernetes_config_map.aws_auth,
  ]
}

resource "kubernetes_cluster_role_binding" "tiller" {
  count = var.helm_enabled ? 1 : 0

  metadata {
    name = kubernetes_service_account.tiller[0].metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.tiller[0].metadata[0].name
    namespace = kubernetes_service_account.tiller[0].metadata[0].namespace
  }
}
