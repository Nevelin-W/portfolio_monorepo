output "certificate_arn" {
  value = aws_acm_certificate.certificate_01.arn
}

output "domain_validation_options" {
  value = aws_acm_certificate.certificate_01.domain_validation_options
}

output "hosted_zone_id" {
  value = var.environment == "dev" ? aws_route53_zone.hosted_zone_01[0].id : null
}
