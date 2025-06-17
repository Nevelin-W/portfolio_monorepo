output "distribution_id" {
  value = aws_cloudfront_distribution.distribution_01.id
}

output "domain_name" {
  value = aws_cloudfront_distribution.distribution_01.domain_name
}

output "hosted_zone_id" {
  value = aws_cloudfront_distribution.distribution_01.hosted_zone_id
}

output "bucket_policy_document" {
  value = data.aws_iam_policy_document.cloudfront_oac_access.json
}
