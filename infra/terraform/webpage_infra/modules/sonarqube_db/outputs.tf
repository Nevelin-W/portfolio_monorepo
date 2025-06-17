output "db_instance_id" {
  description = "ID of the RDS instance"
  value       = aws_db_instance.sonarqube.id
}

output "db_instance_endpoint" {
  description = "Connection endpoint for the RDS instance"
  value       = aws_db_instance.sonarqube.endpoint
}

output "db_instance_name" {
  description = "Name of the database"
  value       = aws_db_instance.sonarqube.db_name
}

output "db_instance_username" {
  description = "Username for the database"
  value       = aws_db_instance.sonarqube.username
  sensitive   = true
}