output "sonarqube_instance_id" {
  description = "ID of the SonarQube EC2 instance"
  value       = aws_instance.sonarqube.id
}

output "sonarqube_public_ip" {
  description = "Public IP of the SonarQube instance"
  value       = aws_eip.sonarqube.public_ip
}

output "sonarqube_url" {
  description = "URL to access SonarQube"
  value       = "http://sonar.${var.domain_name}:9000"
}

output "sonarqube_dns" {
  description = "DNS name for SonarQube"
  value       = aws_route53_record.sonarqube.fqdn
}