resource "aws_acm_certificate" "certificate_01" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  tags = {
    ManagedByTf = "Yes"
    Environment = upper(var.environment)
    Name        = "${upper(var.environment)}-ACM-CERTIFICATE"
  }

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_route53_zone" "zone" {
  name = var.root_domain
}

resource "aws_route53_zone" "hosted_zone_01" {
  count = var.environment == "dev" ? 1 : 0
  name  = var.root_domain

  tags = {
    ManagedByTf = "Yes"
    Environment = "SHARED"
  }
}

resource "aws_route53_record" "domain_validation_01" {
  for_each = {
    for dvo in aws_acm_certificate.certificate_01.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  name    = each.value.name
  records = [each.value.record]
  ttl     = 60
  type    = each.value.type
  zone_id = data.aws_route53_zone.zone.zone_id
}

resource "aws_acm_certificate_validation" "certificate_validatio_01" {
  certificate_arn         = aws_acm_certificate.certificate_01.arn
  validation_record_fqdns = [for record in aws_route53_record.domain_validation_01 : record.fqdn]
}

resource "aws_route53_record" "domain_record" {
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.cloudfront_domain_name
    zone_id                = var.cloudfront_hosted_zone_id
    evaluate_target_health = false
  }
}
