provider "aws" {
  region = var.region
}

module "s3_webpage" {
  source        = "../../modules/s3/webpage"
  bucket_name   = var.bucket_name
  bucket_policy = module.cloudfront.bucket_policy_document
  environment   = var.environment
}

module "s3_artifacts" {
  source        = "../../modules/s3/artifacts"
  bucket_name   = var.bucket_name
  project_name   = var.project_name
  environment   = var.environment
  github_org = var.github_org
  github_repo = var.github_repo
  region        = var.region
  root_domain   = var.root_domain
  bucket_arn                  = module.s3_webpage.bucket_arn
}

module "cloudfront" {
  source                      = "../../modules/cloudfront"
  domain_name                 = var.domain_name
  bucket_name                 = module.s3_webpage.bucket_name
  bucket_regional_domain_name = module.s3_webpage.bucket_regional_domain_name
  bucket_arn                  = module.s3_webpage.bucket_arn
  acm_certificate_arn         = module.acm.certificate_arn
  region                      = var.region
  environment                 = var.environment
  allowed_ips                 = var.allowed_ips  
  allowed_cidrs               = var.allowed_cidrs 
  debug_mode                  = var.debug
}

module "acm" {
  source                    = "../../modules/acm"
  domain_name               = var.domain_name
  root_domain               = var.root_domain
  region                    = var.region
  cloudfront_domain_name    = module.cloudfront.domain_name
  cloudfront_hosted_zone_id = module.cloudfront.hosted_zone_id
  environment               = var.environment
}


module "vpc" {
  source              = "../../modules/vpc"
  name                = "sonarqube"
  cidr_block          = "10.0.0.0/16"
  azs                 = ["us-east-1a", "us-east-1b"]
  public_subnet_count = 2
  environment         = var.environment
}

module "sonarqube" {
  source            = "../../modules/sonarqube"
  ami_id            = var.ami_id
  instance_type     = var.instance_type
  key_name          = var.key_name
  subnet_id         = module.vpc.public_subnet_ids[0]
  security_group_id = module.sonarqube_security.security_group_sonar_id
  iam_instance_profile_name = module.sonarqube_security.iam_instance_profile_name
  volume_size       = var.volume_size
  environment       = var.environment
  hosted_zone_id    = module.acm.hosted_zone_id
  domain_name       = var.domain_name
  vpc_id            = module.vpc.vpc_id
}


module "sonarqube_security" {
  source                        = "../../modules/sonarqube_security"
  environment                   = var.environment
  vpc_id                        = module.vpc.vpc_id
  sonarqube_allowed_cidr_blocks = var.sonarqube_allowed_cidr_blocks
  ssh_allowed_cidr_blocks       = var.ssh_allowed_cidr_blocks
}

module "sonarqube_db" {
  source = "../../modules/sonarqube_db"

  environment           = var.environment
  database_subnet_ids   = module.vpc.public_subnet_ids
  db_instance_class     = var.db_instance_class
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  db_name               = var.db_name
  db_username           = var.db_username
  db_password           = var.db_password
  db_security_group_id  = module.sonarqube_security.security_group_db_id
}
