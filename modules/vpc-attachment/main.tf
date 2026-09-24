resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  transit_gateway_id = var.transit_gateway_id
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids

  dns_support            = var.dns_support ? "enable" : "disable"
  ipv6_support           = var.ipv6_support ? "enable" : "disable"
  appliance_mode_support = var.appliance_mode_support ? "enable" : "disable"

  tags = merge(var.tags, {
    Name = var.name
  })
}

resource "aws_ec2_transit_gateway_route_table_association" "this" {
  count = var.transit_gateway_route_table_id == null ? 0 : 1

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this.id
  transit_gateway_route_table_id = var.transit_gateway_route_table_id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "this" {
  count = var.transit_gateway_route_table_id == null || !var.enable_propagation ? 0 : 1

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this.id
  transit_gateway_route_table_id = var.transit_gateway_route_table_id

  depends_on = [aws_ec2_transit_gateway_route_table_association.this]
}

resource "aws_route" "this" {
  for_each = var.routes

  route_table_id              = each.value.route_table_id
  destination_cidr_block      = each.value.destination_cidr_block
  destination_ipv6_cidr_block = each.value.destination_ipv6_cidr_block
  transit_gateway_id          = var.transit_gateway_id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.this]
}
