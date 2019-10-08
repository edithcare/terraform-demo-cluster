resource "aws_subnet" "private" {
  count                   = length(data.aws_availability_zones.this.names)
  vpc_id                  = aws_vpc.this.id
  availability_zone       = data.aws_availability_zones.this.names[count.index]
  map_public_ip_on_launch = false
  cidr_block = cidrsubnet(
    aws_vpc.this.cidr_block,
    ceil(log(length(var.subnets), 2)) + ceil(log(length(data.aws_availability_zones.this.names), 2)),
    index(var.subnets, "private") * length(data.aws_availability_zones.this.names) + count.index
  )
  tags = merge(var.tags,
    {
      Name       = "${var.name}-private-${data.aws_availability_zones.this.names[count.index]}"
      SubnetType = "private"
    },
    {
      "kubernetes.io/cluster/${var.name}" = "owned"
    }
  )
}


resource "aws_route_table" "private" {
  count = length(aws_subnet.private)

  vpc_id = aws_vpc.this.id
  tags = merge(var.tags,
    {
      Name = "${var.name}-private-${data.aws_availability_zones.this.names[count.index]}"
    }
  )
}


resource "aws_route" "private" {
  count = length(aws_subnet.private)

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[count.index].id
}


resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}


resource "aws_flow_log" "private" {
  count = var.enable_flow_logs ? length(data.aws_availability_zones.this.names) : 0

  iam_role_arn    = aws_iam_role.vpc_flow_logs[0].arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs[0].arn
  traffic_type    = var.flow_log_traffic_type
  subnet_id       = aws_subnet.private[count.index].id
}


resource "aws_network_acl" "private" {
  count = var.enable_network_acls ? length(data.aws_availability_zones.this.names) : 0

  vpc_id     = aws_vpc.this.id
  subnet_ids = [aws_subnet.private[count.index].id]

  tags = merge(var.tags,
    {
      Name = "${var.name}-private-${data.aws_availability_zones.this.names[count.index]}"
    }
  )
}

# TODO: Restrict this
resource "aws_network_acl_rule" "private_egress_all" {
  count = var.enable_network_acls ? length(data.aws_availability_zones.this.names) : 0

  network_acl_id = aws_network_acl.private[count.index].id
  rule_number    = 1
  egress         = true
  protocol       = "all"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
}


# TODO: Restrict this
resource "aws_network_acl_rule" "private_ingress_all" {
  count = var.enable_network_acls ? length(data.aws_availability_zones.this.names) : 0

  network_acl_id = aws_network_acl.private[count.index].id
  rule_number    = 1
  egress         = false
  protocol       = "all"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
}


# # TODO: Enable more restricted rules like this.
# # Allow HTTPS inbound traffic from load balancer subnet
# resource "aws_network_acl_rule" "private_ingress_https" {
#   network_acl_id = aws_network_acl.private.id
#   rule_number    = aws_network_acl_rule.private_egress.rule_number + 1
#   egress         = false
#   protocol       = "tcp"
#   rule_action    = "allow"
#   cidr_block     = cidrsubnet(
#     aws_vpc.this.cidr_block,
#     ceil(log(length(var.subnets), 2)),
#     index(var.subnets, "public")
#   )
#   from_port      = 443
#   to_port        = 443
# }
