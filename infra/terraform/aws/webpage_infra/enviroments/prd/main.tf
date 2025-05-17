provider "aws" {
  region = var.region
}

module "s3" {
  source        = "../../modules/s3"
  bucket_name   = var.bucket_name
  bucket_policy = module.cloudfront.bucket_policy_document
  environment   = "prd"
}

module "cloudfront" {
  source                      = "../../modules/cloudfront"
  domain_name                 = var.domain_name
  bucket_name                 = module.s3.bucket_name
  bucket_regional_domain_name = module.s3.bucket_regional_domain_name
  bucket_arn                  = module.s3.bucket_arn
  acm_certificate_arn         = module.acm.certificate_arn
  region                      = var.region
  environment                 = "prd"
  allowed_ips                 = [] # Empty list for production as it's publicly accessible
}

module "acm" {
  source                    = "../../modules/acm"
  domain_name               = var.domain_name
  root_domain               = var.root_domain
  region                    = var.region
  cloudfront_domain_name    = module.cloudfront.domain_name
  cloudfront_hosted_zone_id = module.cloudfront.hosted_zone_id
  environment               = "prd"
}
