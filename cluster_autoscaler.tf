# https://docs.aws.amazon.com/autoscaling/ec2/userguide/control-access-using-iam.html
resource "aws_iam_policy" "cluster_autoscaler" {
  count = var.cluster_autoscaler_enabled ? 1 : 0

  name   = "ClusterAutoscaler-${var.name}"
  policy = <<-EOD
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Action": [
            "autoscaling:DescribeAutoScalingGroups",
            "autoscaling:DescribeAutoScalingInstances",
            "autoscaling:SetDesiredCapacity",
            "autoscaling:TerminateInstanceInAutoScalingGroup",
            "autoscaling:DescribeTags"
          ],
          "Resource": "${aws_autoscaling_group.default.arn}"
        }
      ]
    }
  EOD
}


data "aws_iam_policy_document" "cluster_autoscaler" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.this.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${var.cluster_autoscaler_namespace}:${var.cluster_autoscaler_service_account}"]
    }

    principals {
      identifiers = ["${aws_iam_openid_connect_provider.this.arn}"]
      type        = "Federated"
    }
  }
}


resource "aws_iam_role" "cluster_autoscaler" {
  count = var.cluster_autoscaler_enabled ? 1 : 0

  assume_role_policy = data.aws_iam_policy_document.cluster_autoscaler.json
  name               = "ClusterAutoscaler-${var.name}"
}


resource "aws_iam_role_policy_attachment" "cluster_autoscaler" {
  count = var.cluster_autoscaler_enabled ? 1 : 0

  policy_arn = aws_iam_policy.cluster_autoscaler[0].arn
  role       = aws_iam_role.cluster_autoscaler[0].name
}


resource "kubernetes_service_account" "cluster_autoscaler" {
  count = var.cluster_autoscaler_enabled ? 1 : 0

  metadata {
    name      = "cluster-autoscaler"
    namespace = "kube-system"
    labels = {
      "k8s-addon" = "cluster-autoscaler.addons.k8s.io"
      "k8s-app"   = "cluster-autoscaler"
    }
    annotations = {
      "managed-by"                 = "terraform"
      "eks.amazonaws.com/role-arn" = aws_iam_role.cluster_autoscaler[0].arn
    }
  }
}


resource "kubernetes_cluster_role" "cluster_autoscaler" {
  count = var.cluster_autoscaler_enabled ? 1 : 0

  metadata {
    name = "cluster-autoscaler"
    labels = {
      "k8s-addon" = "cluster-autoscaler.addons.k8s.io"
      "k8s-app"   = "cluster-autoscaler"
    }
    annotations = {
      "managed-by" = "terraform"
    }
  }
  rule {
    api_groups = [""]
    resources  = ["events", "endpoints"]
    verbs      = ["create", "patch"]
  }
  rule {
    api_groups = [""]
    resources  = ["pods/eviction"]
    verbs      = ["create"]
  }
  rule {
    api_groups = [""]
    resources  = ["pods/status"]
    verbs      = ["update"]
  }
  rule {
    api_groups     = [""]
    resources      = ["endpoints"]
    resource_names = ["cluster-autoscaler"]
    verbs          = ["get", "update"]
  }
  rule {
    api_groups = [""]
    resources  = ["nodes"]
    verbs      = ["watch", "list", "get", "update"]
  }
  rule {
    api_groups = [""]
    resources  = ["pods", "services", "replicationcontrollers", "persistentvolumeclaims", "persistentvolumes"]
    verbs      = ["watch", "list", "get"]
  }
  rule {
    api_groups = ["extensions"]
    resources  = ["replicasets", "daemonsets"]
    verbs      = ["watch", "list", "get"]
  }
  rule {
    api_groups = ["policy"]
    resources  = ["poddisruptionbudgets"]
    verbs      = ["watch", "list"]
  }
  rule {
    api_groups = ["apps"]
    resources  = ["statefulsets"]
    verbs      = ["watch", "list", "get"]
  }
  rule {
    api_groups = ["storage.k8s.io"]
    resources  = ["storageclasses"]
    verbs      = ["watch", "list", "get"]
  }
}


resource "kubernetes_role" "cluster_autoscaler" {
  count = var.cluster_autoscaler_enabled ? 1 : 0

  metadata {
    name      = "cluster-autoscaler"
    namespace = "kube-system"
    labels = {
      "k8s-addon" = "cluster-autoscaler.addons.k8s.io"
      "k8s-app"   = "cluster-autoscaler"
    }
    annotations = {
      "managed-by" = "terraform"
    }
  }
  rule {
    api_groups = [""]
    resources  = ["configmaps"]
    verbs      = ["create"]
  }
  rule {
    api_groups     = [""]
    resources      = ["configmaps"]
    resource_names = ["cluster-autoscaler-status"]
    verbs          = ["delete", "get", "update"]
  }
}


resource "kubernetes_cluster_role_binding" "cluster-autoscaler" {
  count = var.cluster_autoscaler_enabled ? 1 : 0

  metadata {
    name = kubernetes_service_account.cluster_autoscaler[0].metadata[0].name
    labels = {
      "k8s-addon" = "cluster-autoscaler.addons.k8s.io"
      "k8s-app"   = "cluster-autoscaler"
    }
    annotations = {
      "managed-by" = "terraform"
    }
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.cluster_autoscaler[0].metadata[0].name
    namespace = kubernetes_service_account.cluster_autoscaler[0].metadata[0].namespace
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.cluster_autoscaler[0].metadata[0].name
  }
}


resource "kubernetes_role_binding" "cluster_autoscaler" {
  count = var.cluster_autoscaler_enabled ? 1 : 0

  metadata {
    name      = kubernetes_service_account.cluster_autoscaler[0].metadata[0].name
    namespace = "kube-system"
    labels = {
      "k8s-addon" = "cluster-autoscaler.addons.k8s.io"
      "k8s-app"   = "cluster-autoscaler"
    }
    annotations = {
      "managed-by" = "terraform"
    }
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.cluster_autoscaler[0].metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.cluster_autoscaler[0].metadata[0].name
    namespace = kubernetes_service_account.cluster_autoscaler[0].metadata[0].namespace
  }
}


resource "kubernetes_deployment" "cluster_autoscaler" {
  count = var.cluster_autoscaler_enabled ? 1 : 0

  metadata {
    name      = "cluster-autoscaler"
    namespace = "kube-system"

    labels = {
      app = "cluster-autoscaler"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "cluster-autoscaler"
      }
    }

    template {
      metadata {
        labels = {
          app = "cluster-autoscaler"
        }
      }

      spec {
        volume {
          name = "ssl-certs"

          host_path {
            path = "/etc/ssl/certs/ca-bundle.crt"
          }
        }

        container {
          name  = "cluster-autoscaler"
          image = "k8s.gcr.io/cluster-autoscaler:v1.2.2"
          command = [
            "./cluster-autoscaler",
            "--v=4",
            "--stderrthreshold=info",
            "--cloud-provider=aws",
            "--skip-nodes-with-local-storage=false",
            "--nodes=2:8:${aws_eks_cluster.this.name}-default"
          ]

          env {
            name  = "AWS_REGION"
            value = "us-west-2"
          }

          resources {
            limits {
              memory = "300Mi"
              cpu    = "100m"
            }

            requests {
              memory = "300Mi"
              cpu    = "100m"
            }
          }

          volume_mount {
            name       = "ssl-certs"
            read_only  = true
            mount_path = "/etc/ssl/certs/ca-certificates.crt"
          }

          image_pull_policy = "Always"
        }

        service_account_name = kubernetes_service_account.cluster_autoscaler[0].metadata[0].name
      }
    }
  }
}
