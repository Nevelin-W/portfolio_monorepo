output "bucket_name" {
  value = aws_s3_bucket.s3_bucket_01.id
}

output "bucket_regional_domain_name" {
  value = aws_s3_bucket.s3_bucket_01.bucket_regional_domain_name
}

output "bucket_arn" {
  value = aws_s3_bucket.s3_bucket_01.arn
}

output "website_endpoint" {
  value = aws_s3_bucket_website_configuration.website_config_01.website_endpoint
}
