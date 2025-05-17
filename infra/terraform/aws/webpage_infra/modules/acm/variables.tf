variable "domain_name" {
  description = "Domain name for the website"
  type        = string
}

variable "root_domain" {
  description = "Root domain for Route53 hosted zone"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution"
  type        = string
}

variable "cloudfront_hosted_zone_id" {
  description = "Hosted zone ID of the CloudFront distribution"
  type        = string
}

variable "environment" {
  description = "Environment (dev or prd)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "prd"], var.environment)
    error_message = "Environment must be either 'dev' or 'prd'."
  }
}
