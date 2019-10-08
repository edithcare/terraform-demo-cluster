resource "aws_subnet" "public" {
  count                   = length(data.aws_availability_zones.this.names)
  vpc_id                  = aws_vpc.this.id
  availability_zone       = data.aws_availability_zones.this.names[count.index]
  map_public_ip_on_launch = true
  cidr_block = cidrsubnet(
    aws_vpc.this.cidr_block,
    ceil(log(length(var.subnets), 2)) + ceil(log(length(data.aws_availability_zones.this.names), 2)),
    index(var.subnets, "public") * length(data.aws_availability_zones.this.names) + count.index
  )
  tags = merge(var.tags,
    {
      Name       = "${var.name}-public-${data.aws_availability_zones.this.names[count.index]}"
      SubnetType = "public"
    },
    {
      "kubernetes.io/cluster/${var.name}" = "owned"
      "kubernetes.io/role/elb"            = 1
    }
  )
}


resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = merge(var.tags,
    {
      Name = "${var.name}-public"
    }
  )
}


resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = "${aws_subnet.public.*.id[count.index]}"
  route_table_id = aws_route_table.public.id
}


resource "aws_flow_log" "public" {
  count = var.enable_flow_logs ? length(data.aws_availability_zones.this.names) : 0

  iam_role_arn    = aws_iam_role.vpc_flow_logs[0].arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs[0].arn
  traffic_type    = var.flow_log_traffic_type
  subnet_id       = aws_subnet.public[count.index].id
}


resource "aws_network_acl" "public" {
  count = var.enable_network_acls ? length(data.aws_availability_zones.this.names) : 0

  vpc_id     = aws_vpc.this.id
  subnet_ids = [aws_subnet.public[count.index].id]

  tags = merge(var.tags,
    {
      Name = "${var.name}-public-${data.aws_availability_zones.this.names[count.index]}"
    }
  )
}


# TODO: Restrict this
resource "aws_network_acl_rule" "public_egress_all" {
  count = var.enable_network_acls ? length(data.aws_availability_zones.this.names) : 0

  network_acl_id = aws_network_acl.public[count.index].id
  rule_number    = 1
  egress         = true
  protocol       = "all"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
}


# TODO: Restrict this
resource "aws_network_acl_rule" "public_ingress_all" {
  count = var.enable_network_acls ? length(data.aws_availability_zones.this.names) : 0

  network_acl_id = aws_network_acl.public[count.index].id
  rule_number    = 1
  egress         = false
  protocol       = "all"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
}


# # TODO: Enable more restricted rules like this.
# # Allow HTTPS inbound traffic from everywhere for load balancer subnet
# resource "aws_network_acl_rule" "public_ingress_https" {
#   network_acl_id = aws_network_acl.public.id
#   rule_number    = 1
#   egress         = false
#   protocol       = "tcp"
#   rule_action    = "allow"
#   cidr_block     = "0.0.0.0/0"
#   from_port      = 443
#   to_port        = 443
# }
