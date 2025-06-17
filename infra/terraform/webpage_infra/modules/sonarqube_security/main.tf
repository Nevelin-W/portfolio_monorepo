# Security groups for SonarQube and database

resource "aws_security_group" "sonarqube" {
  name        = "${var.environment}-sonarqube-sg"
  description = "Security group for SonarQube EC2 instance"
  vpc_id      = var.vpc_id

  # HTTP access
  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = var.sonarqube_allowed_cidr_blocks
    description = "SonarQube web interface"
  }

  # SSH access (optional - for management)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_allowed_cidr_blocks
    description = "SSH access"
  }

  # Outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    ManagedByTf = "Yes"
    Name        = "${var.environment}-sonarqube-sg"
    Environment = var.environment
  }
}

resource "aws_security_group" "sonarqube_db" {
  name        = "${var.environment}-sonarqube-db-sg"
  description = "Security group for SonarQube database"
  vpc_id      = var.vpc_id

  # PostgreSQL access from SonarQube only
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.sonarqube.id]
    description     = "PostgreSQL access from SonarQube"
  }

  # Outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    ManagedByTf = "Yes"
    Name        = "${var.environment}-sonarqube-db-sg"
    Environment = var.environment
  }
}

# IAM role for EC2 instance to access other AWS services
resource "aws_iam_role" "sonarqube" {
  name = "${var.environment}-sonarqube-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    ManagedByTf = "Yes"
    Name        = "${var.environment}-sonarqube-role"
    Environment = var.environment
  }
}

# IAM policy for SSM Parameter Store access
resource "aws_iam_policy" "sonarqube_ssm" {
  name        = "${var.environment}-sonarqube-ssm-policy"
  description = "Policy for SonarQube to access SSM Parameter Store"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:PutParameter"
        ]
        Resource = "arn:aws:ssm:*:*:parameter/${var.environment}/sonarqube/*"
      }
    ]
  })
}

# Attach SSM policy to role
resource "aws_iam_role_policy_attachment" "sonarqube_ssm" {
  role       = aws_iam_role.sonarqube.name
  policy_arn = aws_iam_policy.sonarqube_ssm.arn
}

# Attach AmazonSSMManagedInstanceCore to role for SSM management
resource "aws_iam_role_policy_attachment" "sonarqube_ssm_core" {
  role       = aws_iam_role.sonarqube.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance profile for EC2
resource "aws_iam_instance_profile" "sonarqube" {
  name = "${var.environment}-sonarqube-profile"
  role = aws_iam_role.sonarqube.name
}

# Lambda execution role (for on-demand start)
resource "aws_iam_role" "lambda_execution" {
  name = "${var.environment}-sonarqube-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    ManagedByTf = "Yes"
    Name        = "${var.environment}-sonarqube-lambda-role"
    Environment = var.environment
  }
}

# Lambda execution policy
resource "aws_iam_policy" "lambda_execution" {
  name        = "${var.environment}-sonarqube-lambda-policy"
  description = "Policy for Lambda to start/stop SonarQube instance"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:StartInstances",
          "ec2:StopInstances",
          "ec2:DescribeInstances",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach policy to Lambda role
resource "aws_iam_role_policy_attachment" "lambda_execution" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = aws_iam_policy.lambda_execution.arn
}