# https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/access-control-managing-permissions.html
resource "aws_iam_policy" "external_dns" {
  count = var.external_dns_enabled ? 1 : 0

  name = "external-dns-${var.name}"

  policy = <<-EOD
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Action": [
            "route53:ChangeResourceRecordSets",
            "route53:ListResourceRecordSets"
          ],
          "Resource": [
            "arn:aws:route53:::hostedzone/${aws_route53_zone.this.id}"
          ]
        },
        {
          "Effect": "Allow",
          "Action": [
            "route53:ListHostedZones"
          ],
          "Resource": [
            "*"
          ]
        }
      ]
    }
  EOD
}



data "aws_iam_policy_document" "external_dns" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.this.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:external-dns:external-dns"]
    }

    principals {
      identifiers = ["${aws_iam_openid_connect_provider.this.arn}"]
      type        = "Federated"
    }
  }
}


resource "aws_iam_role" "external_dns" {
  count = var.external_dns_enabled ? 1 : 0

  assume_role_policy = data.aws_iam_policy_document.external_dns.json
  name               = "external-dns-${var.name}"
}


resource "aws_iam_role_policy_attachment" "external_dns" {
  count = var.external_dns_enabled ? 1 : 0

  policy_arn = aws_iam_policy.external_dns[0].arn
  role       = aws_iam_role.external_dns[0].name
}


resource "kubernetes_namespace" "external_dns" {
  count = var.external_dns_enabled ? 1 : 0

  metadata {
    name = "external-dns"

    annotations = {
      "managed-by" = "terraform"
    }
  }
}


resource "kubernetes_service_account" "external_dns" {
  count = var.external_dns_enabled ? 1 : 0

  metadata {
    name      = "external-dns"
    namespace = "external-dns"
    annotations = {
      "managed-by"                 = "terraform"
      "eks.amazonaws.com/role-arn" = aws_iam_role.external_dns[0].arn
    }
  }
}


resource "kubernetes_cluster_role" "external_dns" {
  count = var.external_dns_enabled ? 1 : 0

  metadata {
    name = "external-dns"
    annotations = {
      "managed-by" = "terraform"
    }
  }

  rule {
    verbs      = ["get", "watch", "list"]
    api_groups = [""]
    resources  = ["services"]
  }

  rule {
    verbs      = ["get", "watch", "list"]
    api_groups = [""]
    resources  = ["pods"]
  }

  rule {
    verbs      = ["get", "watch", "list"]
    api_groups = ["extensions"]
    resources  = ["ingresses"]
  }

  rule {
    verbs      = ["list", "watch"]
    api_groups = [""]
    resources  = ["nodes"]
  }
}


resource "kubernetes_cluster_role_binding" "external_dns" {
  count = var.external_dns_enabled ? 1 : 0

  metadata {
    name = kubernetes_service_account.external_dns[0].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.external_dns[0].metadata[0].name
    namespace = kubernetes_service_account.external_dns[0].metadata[0].namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "external-dns"
  }
}

# resource "kubernetes_deployment" "external_dns" {
#   count = var.external_dns_enabled ? 1 : 0

#   metadata {
#     name = "external-dns"
#   }

#   spec {
#     template {
#       metadata {
#         labels = {
#           app = "external-dns"
#         }
#       }

#       spec {
#         container {
#           name  = "external-dns"
#           image = "registry.opensource.zalan.do/teapot/external-dns:latest"
#           args = [
#             "--source=service",
#             "--source=ingress",
#             "--domain-filter=external-dns-test.my-org.com",
#             "--provider=aws",
#             "--policy=upsert-only",
#             "--aws-zone-type=public",
#             "--registry=txt",
#             "--txt-owner-id=${aws_route53_zone.this.id}"
#           ]
#         }

#         service_account_name = kubernetes_service_account.external_dns[0].metadata[0].name

#         security_context {
#           fs_group = 65534
#         }
#       }
#     }

#     strategy {
#       type = "Recreate"
#     }
#   }
# }


resource "kubernetes_deployment" "external_dns" {
  count = var.external_dns_enabled ? 1 : 0

  metadata {
    name = "external-dns"
    namespace = "external-dns"

    labels = {
      app = "external-dns"
    }
  }

  spec {

    selector {
      match_labels = {
        app = "external-dns"
      }
    }

    template {
      metadata {
        labels = {
          app = "external-dns"
        }
      }

      spec {
        container {
          name  = "external-dns"
          image = "registry.opensource.zalan.do/teapot/external-dns:latest"
          args  = ["--source=service", "--source=ingress", "--domain-filter=external-dns-test.my-org.com", "--provider=aws", "--policy=upsert-only", "--aws-zone-type=public", "--registry=txt", "--txt-owner-id=my-hostedzone-identifier"]
        }

        service_account_name = kubernetes_service_account.external_dns[0].metadata[0].name

        security_context {
          fs_group = 65534
        }
      }
    }

    strategy {
      type = "Recreate"
    }
  }
}
