# RDS PostgreSQL database for SonarQube

resource "aws_db_subnet_group" "sonarqube" {
  name       = "${var.environment}-sonarqube-subnet-group"
  subnet_ids = var.database_subnet_ids

  tags = {
    Name        = "${var.environment}-sonarqube-subnet-group"
    Environment = var.environment
  }
}

resource "aws_db_instance" "sonarqube" {
  identifier             = "${var.environment}-sonarqube"
  engine                 = "postgres"
  engine_version         = "15.8"
  instance_class         = var.db_instance_class
  allocated_storage      = var.allocated_storage
  storage_type           = "gp3"
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.sonarqube.name
  vpc_security_group_ids = [var.db_security_group_id]
  skip_final_snapshot    = true

  # Enable storage autoscaling
  max_allocated_storage = var.max_allocated_storage

  # Maintenance and backup settings
  backup_retention_period = var.environment == "prod" ? 7 : 1
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  # Performance insights
  performance_insights_enabled = var.environment == "prod" ? true : false

  # Add parameter group if needed for specific PostgreSQL settings
  parameter_group_name = aws_db_parameter_group.sonarqube.name

  tags = {
    Name        = "${var.environment}-sonarqube-db"
    Environment = var.environment
  }
}

resource "aws_db_parameter_group" "sonarqube" {
  name   = "${var.environment}-sonarqube-pg"
  family = "postgres15"

  parameter {
    name         = "max_connections"
    value        = "100"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "shared_buffers"
    value        = "131072"
    apply_method = "pending-reboot"
  }

  tags = {
    Name        = "${var.environment}-sonarqube-parameter-group"
    Environment = var.environment
  }
}

# Store database credentials in SSM Parameter Store
resource "aws_ssm_parameter" "db_endpoint" {
  name  = "/${var.environment}/sonarqube/db_endpoint"
  type  = "String"
  value = aws_db_instance.sonarqube.endpoint
  tags = {
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "db_username" {
  name  = "/${var.environment}/sonarqube/db_username"
  type  = "SecureString"
  value = var.db_username
  tags = {
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "db_password" {
  name  = "/${var.environment}/sonarqube/db_password"
  type  = "SecureString"
  value = var.db_password
  tags = {
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "db_name" {
  name  = "/${var.environment}/sonarqube/db_name"
  type  = "String"
  value = var.db_name
  tags = {
    Environment = var.environment
  }
}