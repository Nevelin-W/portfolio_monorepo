output "security_group_sonar_id" {
  value = aws_security_group.sonarqube.id
}

output "security_group_db_id" {
  value = aws_security_group.sonarqube_db.id
}

output "iam_instance_profile_name" {
  value = aws_iam_instance_profile.sonarqube.name
}