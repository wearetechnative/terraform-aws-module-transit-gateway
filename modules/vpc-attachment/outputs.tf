output "id" {
  description = "Transit gateway VPC attachment ID."
  value       = aws_ec2_transit_gateway_vpc_attachment.this.id
}

output "arn" {
  description = "Transit gateway VPC attachment ARN."
  value       = aws_ec2_transit_gateway_vpc_attachment.this.arn
}
