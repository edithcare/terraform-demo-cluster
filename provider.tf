
provider "aws" {
  version = "~> 2.30"
  region  = "eu-central-1"
}


provider "null" {
  version = "~> 2.1"
}


provider "local" {
  version = "~> 1.4"
}


data "aws_eks_cluster_auth" "this" {
  name = aws_eks_cluster.this.name
}


provider "kubernetes" {
  version = "~> 1.9"

  host                   = aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.this.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.this.token
  load_config_file       = false
}


provider helm {
  version = "~> 0.10"

  install_tiller = true
  tiller_image   = "gcr.io/kubernetes-helm/tiller:v2.14.3"
  namespace      = kubernetes_service_account.tiller.metadata.0.namespace

  # Enable TLS so Helm can communicate with Tiller securely.
  enable_tls = false

  service_account = kubernetes_service_account.tiller.metadata.0.name
  kubernetes {
    host                   = aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.this.certificate_authority.0.data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}
