variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where resources will be created"
  type        = string
}

variable "sonarqube_allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access SonarQube"
  type        = list(string)
  default     = []  # Open to all by default, but should be restricted
}

variable "ssh_allowed_cidr_blocks" {
  description = "CIDR blocks allowed to SSH into the SonarQube instance"
  type        = list(string)
  default     = []  # Open to all by default, but should be restricted
}