variable "environment" {
  description = "Environment name (dev, prod, etc.)"
  type        = string
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
}

variable "subnet_id" {
  description = "Subnet ID for the EC2 instance"
  type        = string
}

variable "security_group_id" {
  description = "Security group ID for the EC2 instance"
  type        = string
}

variable "volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 10
}

variable "domain_name" {
  description = "Domain name for SonarQube"
  type        = string
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "enable_automatic_shutdown" {
  description = "Whether to enable automatic shutdown of the SonarQube instance"
  type        = bool
  default     = true
}

variable "iam_instance_profile_name" {
  description = "IAM instance profile name for the SonarQube EC2 instance"
  type        = string
}