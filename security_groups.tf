# https://docs.aws.amazon.com/en_pv/vpc/latest/userguide/VPC_SecurityGroups.html

# Control plane security group
resource "aws_security_group" "control_plane" {
  name        = "${var.name}-control-plane"
  description = "EKS: ${var.name} control plane"
  vpc_id      = aws_vpc.this.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags,
    {
      Name                                = "${var.name}-control-plane"
      "kubernetes.io/cluster/${var.name}" = "owned"
    }
  )
}

# Node security group
resource "aws_security_group" "node" {
  name        = "${var.name}-node"
  description = "EKS: ${var.name} nodes"
  vpc_id      = aws_vpc.this.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags,
    {
      Name                                = "${var.name}-node"
      "kubernetes.io/cluster/${var.name}" = "owned"
    }
  )
}

resource "aws_security_group_rule" "node_node" {
  description              = "Allow nodes to communicate with each other"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.node.id
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "node_control_plane" {
  description              = "Allow worker Kubelets and pods to receive communication from control plane"
  from_port                = 1025
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.control_plane.id
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "control_plane_node" {
  description              = "Allow nodes to communicate with control plane"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.control_plane.id
  source_security_group_id = aws_security_group.node.id
  to_port                  = 443
  type                     = "ingress"
}

resource "aws_security_group_rule" "control_plane_all" {
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow to communicate with the control plane"
  from_port         = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.control_plane.id
  to_port           = 443
  type              = "ingress"
}

# Enable the following rule when for Istio
# https://github.com/istio/istio/issues/10637
# ... and probably for cert manager, too
# https://github.com/jetstack/cert-manager/issues/2109
resource "aws_security_group_rule" "node_control_plane_https" {
  description              = "Allow HTTPS from control plane to nodes"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.control_plane.id
  to_port                  = 443
  type                     = "ingress"
}
