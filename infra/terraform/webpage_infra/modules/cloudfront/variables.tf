variable "domain_name" {
  description = "Domain name for the website"
  type        = string
}

variable "bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
}

variable "bucket_regional_domain_name" {
  description = "Regional domain name of the S3 bucket"
  type        = string
}

variable "bucket_arn" {
  description = "ARN of the S3 bucket"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate"
  type        = string
}

variable "region" {
  description = "AWS region"
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

variable "allowed_ips" {
  description = "List of allowed IP addresses for dev environment"
  type        = list(string)
  default     = []
}

variable "allowed_cidrs" {
  description = "List of CIDR ranges allowed to access the resource"
  type        = list(string)
  default     = []
}

variable "debug_mode" {
  description = "Enable debug mode logging"
  type        = bool
  default     = false
}
