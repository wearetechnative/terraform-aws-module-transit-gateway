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

resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  for_each = var.vpc_attachments

  transit_gateway_id = aws_ec2_transit_gateway.this.id
  vpc_id             = each.value.vpc_id
  subnet_ids         = each.value.subnet_ids

  dns_support            = each.value.dns_support ? "enable" : "disable"
  ipv6_support           = each.value.ipv6_support ? "enable" : "disable"
  appliance_mode_support = each.value.appliance_mode_support ? "enable" : "disable"

  tags = merge(var.tags, each.value.tags, {
    Name = coalesce(each.value.name, "${var.name}-${each.key}")
  })
}

locals {
  managed_attachments = {
    for key, attachment in var.vpc_attachments : key => {
      id                       = aws_ec2_transit_gateway_vpc_attachment.this[key].id
      association_route_table  = attachment.association_route_table
      propagation_route_tables = attachment.propagation_route_tables
    }
  }

  external_attachments = {
    for key, attachment in var.attachments : key => {
      id                       = attachment.id
      association_route_table  = attachment.association_route_table
      propagation_route_tables = attachment.propagation_route_tables
    }
  }

  all_attachments = merge(local.managed_attachments, local.external_attachments)

  vpc_routes = merge([
    for attachment_key, attachment in var.vpc_attachments : {
      for route_key, route in attachment.routes :
      "${attachment_key}:${route_key}" => route
    }
  ]...)
}

resource "aws_route" "transit_gateway" {
  for_each = local.vpc_routes

  route_table_id              = each.value.route_table_id
  destination_cidr_block      = each.value.destination_cidr_block
  destination_ipv6_cidr_block = each.value.destination_ipv6_cidr_block
  transit_gateway_id          = aws_ec2_transit_gateway.this.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.this]
}

resource "aws_ec2_transit_gateway_route_table_association" "this" {
  for_each = local.all_attachments

  transit_gateway_attachment_id  = each.value.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.this[each.value.association_route_table].id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment_accepter.this]
}

locals {
  propagations = merge([
    for attachment_key, attachment in local.all_attachments : {
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
