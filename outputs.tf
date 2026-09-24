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

output "route_table_id" {
  description = "ID of the transit gateway route table."
  value       = aws_ec2_transit_gateway_route_table.this.id
}

output "resource_share_arn" {
  description = "AWS RAM resource share ARN, or null when sharing is disabled."
  value       = var.resource_share == null ? null : aws_ram_resource_share.this[0].arn
}
