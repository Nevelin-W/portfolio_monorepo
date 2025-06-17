variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
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
}

variable "db_password" {
  description = "Password for the SonarQube database"
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "DB instance class"
  type        = string
  default     = "db.t3.small"
}

variable "allocated_storage" {
  description = "Allocated storage for the database in GB"
  type        = number
  default     = 10
}

variable "max_allocated_storage" {
  description = "Maximum allocated storage for the database in GB"
  type        = number
  default     = 15
}

variable "database_subnet_ids" {
  description = "List of subnet IDs for the database subnet group"
  type        = list(string)
}

variable "db_security_group_id" {
  description = "Security group ID for the database"
  type        = string
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = false
}