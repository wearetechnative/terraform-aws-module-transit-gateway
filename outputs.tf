output "id" {
  description = "Transit gateway ID."
  value       = aws_ec2_transit_gateway.this.id
}

output "arn" {
  description = "Transit gateway ARN."
  value       = aws_ec2_transit_gateway.this.arn
}

output "owner_id" {
  description = "AWS account ID that owns the transit gateway."
  value       = aws_ec2_transit_gateway.this.owner_id
}

output "route_table_ids" {
  description = "Transit gateway route table IDs keyed by their configured logical names."
  value = {
    for key, route_table in aws_ec2_transit_gateway_route_table.this :
    key => route_table.id
  }
}

output "vpc_attachment_ids" {
  description = "VPC attachment IDs created by this module, keyed by their configured names."
  value = {
    for key, attachment in aws_ec2_transit_gateway_vpc_attachment.this :
    key => attachment.id
  }
}

output "resource_share_arn" {
  description = "AWS RAM resource share ARN, or null when sharing is disabled."
  value       = var.resource_share == null ? null : aws_ram_resource_share.this[0].arn
}
