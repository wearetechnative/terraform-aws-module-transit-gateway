resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  transit_gateway_id = var.transit_gateway_id
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids

  dns_support            = var.dns_support ? "enable" : "disable"
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

locals {
  route_combinations = setproduct(
    var.route_table_ids,
    var.destination_cidr_blocks,
  )

  # Create one route for every route table and destination combination.
  routes = {
    for route in local.route_combinations :
    "${route[0]}:${route[1]}" => {
      route_table_id         = route[0]
      destination_cidr_block = route[1]
    }
  }
}

resource "aws_route" "this" {
  for_each = local.routes

  route_table_id         = each.value.route_table_id
  destination_cidr_block = each.value.destination_cidr_block
  transit_gateway_id     = var.transit_gateway_id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.this]
}
