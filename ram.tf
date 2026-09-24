resource "aws_ram_resource_share" "this" {
  count = var.resource_share == null ? 0 : 1

  name = coalesce(
    var.resource_share == null ? null : var.resource_share.name,
    "${var.name}-transit-gateway"
  )
  allow_external_principals = var.resource_share == null ? false : var.resource_share.allow_external_principals

  tags = merge(var.tags, var.resource_share == null ? {} : var.resource_share.tags)
}

resource "aws_ram_resource_association" "this" {
  count = var.resource_share == null ? 0 : 1

  resource_arn       = aws_ec2_transit_gateway.this.arn
  resource_share_arn = aws_ram_resource_share.this[0].arn
}

resource "aws_ram_principal_association" "this" {
  for_each = var.resource_share == null ? toset([]) : var.resource_share.principals

  principal          = each.value
  resource_share_arn = aws_ram_resource_share.this[0].arn
}
