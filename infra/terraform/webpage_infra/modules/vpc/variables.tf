variable "name" {
  description = "Name prefix"
  type        = string
}

variable "cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "azs" {
  description = "List of availability zones"
  type        = list(string)
}

variable "public_subnet_count" {
  description = "Number of public subnets to create"
  type        = number
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