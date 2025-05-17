variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "domain_name" {
  description = "Domain name for the website"
  type        = string
  default     = "dev.rksmits.com"
}

variable "root_domain" {
  description = "Root domain for Route53 hosted zone"
  type        = string
  default     = "rksmits.com"
}

variable "bucket_name" {
  description = "Name of the S3 bucket for website content"
  type        = string
  default     = "dev.rksmits.com"
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

variable "allowed_ips" {
  description = "List of allowed IP addresses for dev environment"
  type        = list(string)
  default     = [] # Replace with your actual IP addresses
}

variable "allowed_cidrs" {
  description = "List of CIDR ranges allowed to access the resource"
  type        = list(string)
  default     = []
}

variable "debug" {
  description = "Enable debug mode logging"
  type        = bool
  default     = true
}
