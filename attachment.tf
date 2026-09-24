resource "aws_ec2_transit_gateway_vpc_attachment_accepter" "this" {
  for_each = {
    for key, attachment in var.attachments : key => attachment
    if attachment.accept
  }

  transit_gateway_attachment_id = each.value.id

  tags = merge(var.tags, each.value.tags, {
    Name = coalesce(each.value.name, "${var.name}-${each.key}")
  })
}

resource "aws_ec2_transit_gateway_route_table_association" "this" {
  for_each = var.attachments

  transit_gateway_attachment_id  = each.value.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.this[each.value.association_route_table].id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment_accepter.this]
}

locals {
  propagations = merge([
    for attachment_key, attachment in var.attachments : {
      for route_table_key in attachment.propagation_route_tables :
      "${attachment_key}:${route_table_key}" => {
        attachment_id   = attachment.id
        route_table_key = route_table_key
      }
    }
  ]...)
}

resource "aws_ec2_transit_gateway_route_table_propagation" "this" {
  for_each = local.propagations

  transit_gateway_attachment_id  = each.value.attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.this[each.value.route_table_key].id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment_accepter.this]
}

resource "aws_ec2_transit_gateway_route" "this" {
  for_each = var.routes

  destination_cidr_block         = each.value.destination_cidr_block
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.this[each.value.route_table].id
  transit_gateway_attachment_id  = each.value.blackhole ? null : each.value.attachment_id
  blackhole                      = each.value.blackhole

  depends_on = [aws_ec2_transit_gateway_vpc_attachment_accepter.this]
}
