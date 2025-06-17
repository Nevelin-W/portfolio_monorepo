variable "bucket_name" {
  description = "Name of the S3 bucket for website content"
  type        = string
}

variable "region" {
  description = "AWS region to deploy resources"
  type        = string
}

variable "environment" {
  description = "Environment (dev or prd)"
  type        = string


  validation {
    condition     = contains(["dev", "prd"], var.environment)
    error_message = "Environment must be either 'dev' or 'prd'."
  }
}

variable "project_name" {
  type        = string
}


variable "root_domain" {
  type        = string
}

variable "github_org" {
  description = "GitHub organization name"
  type        = string
  
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "bucket_arn" {
  description = "ARN of the S3 bucket"
  type        = string
}