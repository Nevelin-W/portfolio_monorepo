# SonarQube EC2 Instance

resource "aws_instance" "sonarqube" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  iam_instance_profile   = var.iam_instance_profile_name

  root_block_device {
    volume_size = var.volume_size
    volume_type = "gp3"
  }

  user_data = file("${path.module}/userdata.sh")

  tags = {
    Name        = "${var.environment}-sonarqube"
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Elastic IP for SonarQube
resource "aws_eip" "sonarqube" {
  domain = "vpc"
  tags = {
    Name        = "${var.environment}-sonarqube-eip"
    Environment = var.environment
  }
}

resource "aws_eip_association" "sonarqube" {
  instance_id   = aws_instance.sonarqube.id
  allocation_id = aws_eip.sonarqube.id
}

# DNS record for SonarQube
resource "aws_route53_record" "sonarqube" {
  zone_id = var.hosted_zone_id
  name    = "sonar.${var.domain_name}"
  type    = "A"
  ttl     = 300
  records = [aws_eip.sonarqube.public_ip]
}

# SSM Parameter to store SonarQube URL
resource "aws_ssm_parameter" "sonarqube_url" {
  name  = "/${var.environment}/sonarqube/url"
  type  = "String"
  value = "http://sonar.${var.domain_name}:9000"
  tags = {
    Environment = var.environment
  }
}

# CloudWatch Alarm to stop the instance after period of inactivity
resource "aws_cloudwatch_metric_alarm" "sonarqube_idle" {
  alarm_name          = "${var.environment}-sonarqube-idle"
  comparison_operator = "LessThanThreshold"

  metric_name        = "CPUUtilization"
  namespace          = "AWS/EC2"
  period             = 300 # 5 minutes
  evaluation_periods = 12  # 12 periods * 5 minutes = 1 hour total
  statistic          = "Average"
  threshold          = "10"
  alarm_description  = "This metric stops the SonarQube instance when CPU is below 10% for 2 hours"

  dimensions = {
    InstanceId = aws_instance.sonarqube.id
  }

  alarm_actions = [
    "arn:aws:automate:${data.aws_region.current.name}:ec2:stop"
  ]
}

# Get current region for use in CloudWatch alarm
data "aws_region" "current" {}
