variable "bucket_name" {
  description = "Name of the S3 bucket for website content"
  type        = string
}

variable "bucket_policy" {
  description = "IAM policy document for the S3 bucket"
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
