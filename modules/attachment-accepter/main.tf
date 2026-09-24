resource "aws_ec2_transit_gateway_vpc_attachment_accepter" "this" {
  count = var.accept_attachment ? 1 : 0

  transit_gateway_attachment_id = var.attachment_id

  tags = merge(var.tags, {
    Name = var.name
  })
}

resource "aws_ec2_transit_gateway_route_table_association" "this" {
  transit_gateway_attachment_id  = var.attachment_id
  transit_gateway_route_table_id = var.transit_gateway_route_table_id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment_accepter.this]
}

resource "aws_ec2_transit_gateway_route_table_propagation" "this" {
  count = var.enable_propagation ? 1 : 0

  transit_gateway_attachment_id  = var.attachment_id
  transit_gateway_route_table_id = var.transit_gateway_route_table_id

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment_accepter.this,
    aws_ec2_transit_gateway_route_table_association.this,
  ]
}
