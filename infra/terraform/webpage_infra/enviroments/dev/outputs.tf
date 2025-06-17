output "cloudfront_distribution_id" {
  value = module.cloudfront.distribution_id
}

output "website_domain" {
  value = var.domain_name
}

output "s3_bucket_name" {
  value = module.s3_webpage.bucket_name
}
