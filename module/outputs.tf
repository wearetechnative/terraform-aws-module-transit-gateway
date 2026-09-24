output "id" {
  description = "Transit gateway VPC attachment ID."
  value       = aws_ec2_transit_gateway_vpc_attachment.this.id
}

output "arn" {
  description = "Transit gateway VPC attachment ARN."
  value       = aws_ec2_transit_gateway_vpc_attachment.this.arn
}

output "vpc_owner_id" {
  description = "AWS account ID that owns the attached VPC."
  value       = aws_ec2_transit_gateway_vpc_attachment.this.vpc_owner_id
}
