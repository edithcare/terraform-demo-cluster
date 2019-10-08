
resource "aws_subnet" "nat" {
  count                   = length(data.aws_availability_zones.this.names)
  vpc_id                  = aws_vpc.this.id
  availability_zone       = data.aws_availability_zones.this.names[count.index]
  map_public_ip_on_launch = true
  cidr_block = cidrsubnet(
    aws_vpc.this.cidr_block,
    ceil(log(length(var.subnets), 2)) + ceil(log(length(data.aws_availability_zones.this.names), 2)),
    index(var.subnets, "nat") * length(data.aws_availability_zones.this.names) + count.index
  )
  tags = merge(var.tags,
    {
      Name       = "${var.name}-nat-${data.aws_availability_zones.this.names[count.index]}"
      SubnetType = "nat"
    },
    {
      "kubernetes.io/cluster/${var.name}" = "owned"
    }
  )
}


resource "aws_route_table" "nat" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = merge(var.tags,
    {
      Name = "${var.name}-nat"
    }
  )
}


resource "aws_route_table_association" "nat" {
  count          = length(aws_subnet.nat)
  subnet_id      = "${aws_subnet.nat.*.id[count.index]}"
  route_table_id = aws_route_table.nat.id
}


resource "aws_eip" "nat" {
  count = length(aws_subnet.private)
  vpc   = true
  tags = merge(var.tags,
    {
      Name = "${var.name}-nat-${data.aws_availability_zones.this.names[count.index]}"
    }
  )
}


# https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html
resource "aws_nat_gateway" "this" {
  count         = length(aws_subnet.private)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.nat[count.index].id
  depends_on    = [aws_internet_gateway.this]
  tags = merge(var.tags,
    {
      Name = "${var.name}-${data.aws_availability_zones.this.names[count.index]}"
    }
  )
}


resource "aws_flow_log" "nat" {
  count = var.enable_flow_logs ? length(data.aws_availability_zones.this.names) : 0

  iam_role_arn    = aws_iam_role.vpc_flow_logs[0].arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs[0].arn
  traffic_type    = var.flow_log_traffic_type
  subnet_id       = aws_subnet.nat[count.index].id
}


resource "aws_network_acl" "nat" {
  count = var.enable_network_acls ? length(data.aws_availability_zones.this.names) : 0

  vpc_id     = aws_vpc.this.id
  subnet_ids = [aws_subnet.nat[count.index].id]

  tags = merge(var.tags,
    {
      Name = "${var.name}-nat-${data.aws_availability_zones.this.names[count.index]}"
    }
  )
}


# Allow all egress traffic for NAT
resource "aws_network_acl_rule" "nat_egress_all" {
  count = var.enable_network_acls ? length(data.aws_availability_zones.this.names) : 0

  network_acl_id = aws_network_acl.nat[count.index].id
  rule_number    = 1
  egress         = true
  protocol       = "all"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
}


resource "aws_network_acl_rule" "nat_ingress_all" {
  count = var.enable_network_acls ? length(data.aws_availability_zones.this.names) : 0

  network_acl_id = aws_network_acl.nat[count.index].id
  rule_number    = 1
  egress         = false
  protocol       = "all"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
}

# resource "aws_network_acl_rule" "nat_ingress_tcp" {
#   count = length(data.aws_availability_zones.this.names)

#   network_acl_id = aws_network_acl.nat[count.index].id
#   rule_number    = 1
#   egress         = false
#   protocol       = "tcp"
#   rule_action    = "allow"
#   cidr_block     = aws_subnet.private[count.index].cidr_block
#   from_port      = 0
#   to_port        = 65535
# }


# resource "aws_network_acl_rule" "nat_ingress_tcp_return" {
#   count = length(data.aws_availability_zones.this.names)

#   network_acl_id = aws_network_acl.nat[count.index].id
#   rule_number    = 2
#   egress         = false
#   protocol       = "tcp"
#   rule_action    = "allow"
#   cidr_block     = "0.0.0.0/0"
#   from_port      = 1024
#   to_port        = 65535
# }


# resource "aws_network_acl_rule" "nat_ingress_ntp" {
#   count = length(data.aws_availability_zones.this.names)

#   network_acl_id = aws_network_acl.nat[count.index].id
#   rule_number    = 3
#   egress         = false
#   protocol       = "udp"
#   rule_action    = "allow"
#   cidr_block     = aws_subnet.private[count.index].cidr_block
#   from_port      = 123
#   to_port        = 123
# }
