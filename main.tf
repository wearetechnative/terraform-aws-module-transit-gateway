resource "aws_ec2_transit_gateway" "this" {
  description                     = coalesce(var.description, var.name)
  amazon_side_asn                 = var.amazon_side_asn
  auto_accept_shared_attachments  = var.auto_accept_shared_attachments ? "enable" : "disable"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  dns_support                     = var.dns_support ? "enable" : "disable"
  vpn_ecmp_support                = var.vpn_ecmp_support ? "enable" : "disable"

  tags = merge(var.tags, {
    Name = var.name
  })
}

resource "aws_ec2_transit_gateway_route_table" "this" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-default"
  })
}
