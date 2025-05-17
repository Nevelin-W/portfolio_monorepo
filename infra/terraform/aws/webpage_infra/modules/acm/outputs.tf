output "certificate_arn" {
  value = aws_acm_certificate.certificate_01.arn
}

output "domain_validation_options" {
  value = aws_acm_certificate.certificate_01.domain_validation_options
}
