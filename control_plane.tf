# IAM role for control plane.
# To check required policy attachments, check EKS user guide.
# https://docs.aws.amazon.com/en_pv/eks/latest/userguide/
resource "aws_iam_role" "control_plane" {
  name               = "EKSControlPlane-${var.name}"
  assume_role_policy = <<-EOD
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
            "Service": "eks.amazonaws.com"
          },
          "Action": "sts:AssumeRole"
        }
      ]
    }
  EOD

  tags = merge(var.tags,
    {
    }
  )
}


# This policy provides Kubernetes the permissions it requires to manage
# resources on your behalf. Kubernetes requires Ec2:CreateTags permissions to
# place identifying information on EC2 resources including but not limited to
# Instances, Security Groups, and Elastic Network Interfaces.
# https://console.aws.amazon.com/iam/home#/policies/arn:aws:iam::aws:policy/AmazonEKSClusterPolicy$jsonEditor
resource "aws_iam_role_policy_attachment" "control_plane_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.control_plane.name
}


# This policy allows Amazon Elastic Container Service for Kubernetes to create
# and manage the necessary resources to operate EKS Clusters.
# https://console.aws.amazon.com/iam/home#/policies/arn:aws:iam::aws:policy/AmazonEKSServicePolicy$jsonEditor
resource "aws_iam_role_policy_attachment" "control_plane_service_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.control_plane.name
}


# The actual control plane.
resource "aws_eks_cluster" "this" {
  name     = var.name
  role_arn = aws_iam_role.control_plane.arn
  version  = var.k8s_version

  # https://docs.aws.amazon.com/eks/latest/userguide/control-plane-logs.html
  enabled_cluster_log_types = var.control_plane_log_enabled ? var.control_plane_log_types : []

  vpc_config {
    security_group_ids = [aws_security_group.control_plane.id]
    subnet_ids         = concat([for s in aws_subnet.private : s.id], [for s in aws_subnet.public : s.id])
  }
}


# OpenID connect provider to utilize IAM roles for service accounts (IRSA)
# https://docs.aws.amazon.com/en_pv/eks/latest/userguide/iam-roles-for-service-accounts.html
resource "aws_iam_openid_connect_provider" "this" {
  client_id_list = ["sts.amazonaws.com"]
  # TODO: Retrieve this dynamically
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]
  url             = aws_eks_cluster.this.identity.0.oidc.0.issuer
}


locals {
  kubeconfig = <<-EOD
    apiVersion: v1
    clusters:
    - cluster:
        server: ${aws_eks_cluster.this.endpoint}
        certificate-authority-data: ${aws_eks_cluster.this.certificate_authority.0.data}
      name: kubernetes
    contexts:
    - context:
        cluster: kubernetes
        user: aws
      name: ${var.name}
    current-context: ${var.name}
    kind: Config
    preferences: {}
    users:
    - name: aws
      user:
        exec:
          apiVersion: client.authentication.k8s.io/v1alpha1
          command: aws-iam-authenticator
          args:
            - "token"
            - "-i"
            - "${var.name}"
  EOD
}
