
resource "aws_iam_role" "node" {
  name = "EKSNode-${var.name}"

  assume_role_policy = <<-EOD
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
            "Service": "ec2.amazonaws.com"
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

resource "aws_iam_role_policy_attachment" "node_worker_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_registry_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node.name
}

resource "aws_iam_instance_profile" "node" {
  name = var.name
  role = aws_iam_role.node.name
}


# Amazon EKS-Optimized AMI
data "aws_ami" "node" {
  filter {
    name = "name"
    values = [
      "amazon-eks-node-${aws_eks_cluster.this.version}-v*"
    ]
  }
  most_recent = true
  owners      = ["amazon"]
}

# Amazon EKS-Optimized AMI with GPU support
data "aws_ami" "gpu_node" {
  filter {
    name = "name"
    values = [
      "amazon-eks-gpu-node-${aws_eks_cluster.this.version}-v*"
    ]
  }
  most_recent = true
  owners      = ["amazon"]
}
# https://docs.aws.amazon.com/eks/latest/userguide/launch-workers.html
locals {
  node_userdata = <<-EOD
    #!/bin/sh
    set -o xtrace
    /etc/eks/bootstrap.sh \
      --apiserver-endpoint '${aws_eks_cluster.this.endpoint}' \
      --b64-cluster-ca '${aws_eks_cluster.this.certificate_authority.0.data}' \
      '${aws_eks_cluster.this.name}'
  EOD
}


resource "aws_launch_configuration" "default" {
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.node.name
  # P instances use GPU AMI, others use regular AMI
  # https://aws.amazon.com/ec2/instance-types/p3/
  # https://docs.aws.amazon.com/eks/latest/userguide/gpu-ami.html
  image_id         = length(regexall("^p[0-9]+", var.instance_type)) > 0 ? data.aws_ami.gpu_node.id : data.aws_ami.node.id
  instance_type    = var.instance_type
  name_prefix      = aws_eks_cluster.this.name
  security_groups  = [aws_security_group.node.id]
  user_data_base64 = base64encode(local.node_userdata)

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "default" {
  desired_capacity     = length(data.aws_availability_zones.this.names)
  launch_configuration = aws_launch_configuration.default.id
  max_size             = length(data.aws_availability_zones.this.names) * 4
  min_size             = length(data.aws_availability_zones.this.names)
  name                 = "${aws_eks_cluster.this.name}-default"
  vpc_zone_identifier  = [for s in aws_subnet.private : s.id]

  tag {
    key                 = "Name"
    value               = "${aws_eks_cluster.this.name}-default"
    propagate_at_launch = true
  }

  tag {
    key                 = "kubernetes.io/cluster/${aws_eks_cluster.this.name}"
    value               = "owned"
    propagate_at_launch = true
  }
}
