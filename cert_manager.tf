
# data "aws_iam_policy_document" "cert_manager" {
#   statement {
#     actions = ["sts:AssumeRoleWithWebIdentity"]
#     effect  = "Allow"

#     condition {
#       test     = "StringEquals"
#       variable = "${replace(aws_iam_openid_connect_provider.this.url, "https://", "")}:sub"
#       values   = ["system:serviceaccount:cert-manager:cert-manager"]
#     }

#     principals {
#       identifiers = ["${aws_iam_openid_connect_provider.this.arn}"]
#       type        = "Federated"
#     }
#   }
# }

# resource "aws_iam_role" "cert_manager" {
#   assume_role_policy = data.aws_iam_policy_document.cert_manager.json
#   name               = "CertManager-${var.name}"
# }

# resource "aws_iam_policy" "cert_manager" {
#   name   = "CertManager-${var.name}"
#   policy = <<-EOD
#     {
#       "Version": "2012-10-17",
#       "Statement": [
#         {
#           "Effect": "Allow",
#           "Action": "route53:GetChange",
#           "Resource": "arn:aws:route53:::change/${aws_route53_zone.this.id}"
#         },
#         {
#           "Effect": "Allow",
#           "Action": "route53:ChangeResourceRecordSets",
#           "Resource": "arn:aws:route53:::hostedzone/${aws_route53_zone.this.id}"
#         },
#         {
#           "Effect": "Allow",
#           "Action": "route53:ListHostedZonesByName",
#           "Resource": "*"
#         }
#       ]
#     }
#   EOD
# }

# resource "aws_iam_role_policy_attachment" "cert_manager" {
#   policy_arn = aws_iam_policy.cert_manager.arn
#   role       = aws_iam_role.cert_manager.name
# }
