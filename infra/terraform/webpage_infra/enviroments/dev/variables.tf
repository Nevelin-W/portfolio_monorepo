variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "portfolio_monorepo" # Replace with your actual VPC ID
}

variable "environment" {
  description = "Environment"
  type        = string
  default     = "dev"
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
  // Placeholder pwd pass actual via action secrets
  default = []
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

variable "sonarqube_allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access SonarQube"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Open to all by default, but should be restricted
}

variable "ssh_allowed_cidr_blocks" {
  description = "CIDR blocks allowed to SSH into the SonarQube instance"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Open to all by default, but should be restricted
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string
  default     = "ami-0c7217cdde317cfec"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium" # minimum for SonarQube?
}

variable "key_name" {
  description = "SSH key name"
  type        = string
  default     = "sonarqube"
}

variable "volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 10
}

variable "enable_automatic_shutdown" {
  description = "Whether to enable automatic shutdown of the SonarQube instance"
  type        = bool
  default     = true
}

variable "db_name" {
  description = "Name for the SonarQube database"
  type        = string
  default     = "sonarqube"
}

variable "db_username" {
  description = "Username for the SonarQube database"
  type        = string
  sensitive   = true
  default     = "sonar_admin"
}

variable "db_password" {
  description = "Password for the SonarQube database"
  type        = string
  sensitive   = true
  // Placeholder pwd pass actual via action secrets
  default = "S0n#rDB!2025$xYz"
}

variable "db_instance_class" {
  description = "DB instance class"
  type        = string
  default     = "db.t3.small"
}

variable "allocated_storage" {
  description = "Allocated storage for the database in GB"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Maximum allocated storage for the database in GB"
  type        = number
  default     = 30
}


variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = false
}

variable "github_org" {
  description = "GitHub organization name"
  type        = string
  default     = "Nevelin-W"

}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "portfolio_monorepo"
}