output "vpc_id" {
  value = aws_vpc.vpc_01.id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = [for subnet in aws_subnet.public_subnets : subnet.id]
}