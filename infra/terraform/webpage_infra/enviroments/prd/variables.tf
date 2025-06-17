variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment"
  type        = string
  default     = "prd"
}

variable "domain_name" {
  description = "Domain name for the website"
  type        = string
  default     = "rksmits.com"
}

variable "root_domain" {
  description = "Root domain for Route53 hosted zone"
  type        = string
  default     = "rksmits.com"
}

variable "bucket_name" {
  description = "Name of the S3 bucket for website content"
  type        = string
  default     = "rksmits.com"
}

variable "AWS_ACCESS_KEY_ID" {
  description = "AWS access key ID"
  type        = string
  sensitive   = true
}

variable "AWS_SECRET_ACCESS_KEY" {
  description = "AWS secret access key"
  type        = string
  sensitive   = true
}
