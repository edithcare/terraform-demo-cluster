

data "helm_repository" "flux" {
  name = "fluxcd"
  url  = "https://charts.fluxcd.io"
}

resource "helm_release" "flux" {
  count = var.flux_enabled ? 1 : 0

  name       = "flux"
  namespace  = "flux"
  repository = data.helm_repository.flux.metadata.0.name
  chart      = "flux"
  version    = "0.14.1"

  set {
    name  = "helmOperator.create"
    value = true
  }

  set {
    name  = "helmOperator.createCRD"
    value = true
  }

  set {
    name  = "rbac.pspEnabled"
    value = true
  }

  set {
    name  = "git.url"
    value = "git@github.com:edithcare/gitops-demo"
  }

  set {
    name  = "git.email"
    value = "fluxcd@edithcare.institute"
  }

  set {
    name  = "git.setAuthor"
    value = true
  }

  set {
    name  = "syncGarbageCollection.enabled"
    value = true
  }

  set {
    name  = "prometheus.enabled"
    value = true
  }

  set {
    name  = "git.branch"
    value = "prod"
  }
  set {
    name  = "git.path"
    value = "overlays/prod"
  }
  set {
    name  = "git.pollInterval"
    value = "1m"
  }
  set {
    name  = "manifestGeneration"
    value = "true"
  }

  depends_on = [
    kubernetes_cluster_role_binding.tiller
  ]
}
