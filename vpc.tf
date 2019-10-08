
resource "aws_vpc" "this" {
  cidr_block = cidrsubnet("10.0.0.0/8", 8, var.id)

  tags = merge(var.tags,
    {
      Name = var.name
    },
    {
      "kubernetes.io/cluster/${var.name}" = "owned"
    }
  )
}


resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags,
    {
      Name = var.name
    }
  )
}


data "aws_availability_zones" "this" {}


# resource "aws_kms_key" "vpc_flow_logs" {
#   count = var.enable_flow_logs ? 1 : 0

#   description = "VPC flow log key for EKS cluster ${var.name}"
# }

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name = var.name
  # kms_key_id = aws_kms_key.vpc_flow_logs[0].key_id

  tags = merge(var.tags,
    {
      Name = var.name
    }
  )
}


resource "aws_iam_role" "vpc_flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name = "VPCFlowLogs-${var.name}"

  assume_role_policy = <<-EOD
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Sid": "",
          "Effect": "Allow",
          "Principal": {
            "Service": "vpc-flow-logs.amazonaws.com"
          },
          "Action": "sts:AssumeRole"
        }
      ]
    }
  EOD
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name = "VPCFlowLogs-${var.name}"
  role = aws_iam_role.vpc_flow_logs[0].id

  policy = <<-EOD
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Action": [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
            "logs:DescribeLogGroups",
            "logs:DescribeLogStreams"
          ],
          "Effect": "Allow",
          "Resource": "*"
        }
      ]
    }
  EOD
}
