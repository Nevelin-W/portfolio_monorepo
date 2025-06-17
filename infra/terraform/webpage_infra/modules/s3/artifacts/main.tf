data "aws_caller_identity" "current" {}
resource "aws_kms_key" "s3_artifacts" {
  description             = "KMS key for S3 artifact storage encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name        = "${var.project_name}-s3-artifacts-key"
    Environment = var.environment
    Purpose     = "S3 Artifact Storage"
  }
}

resource "aws_kms_alias" "s3_artifacts" {
  name          = "alias/${var.project_name}-s3-artifacts"
  target_key_id = aws_kms_key.s3_artifacts.key_id
}

resource "aws_s3_bucket" "artifacts" {
  bucket = "${var.root_domain}-artifacts-shared"

  tags = {
    Name        = "${var.root_domain}-artifacts"
    Environment = var.environment
    Purpose     = "Build Artifact Storage"
  }
}

# S3 bucket versioning
resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_artifacts.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# S3 bucket public access block
resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket lifecycle configuration
resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  

  rule {
    id     = "artifact_lifecycle"
    status = "Enabled"
    filter {
        prefix = "artifacts/"
    }

    # Transition artifacts to IA after 30 days
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    # Transition artifacts to Glacier after 60 days
    transition {
      days          = 60
      storage_class = "GLACIER"
    }

    # Delete artifacts after retention period
    expiration {
      days = 90
    }

    # Clean up incomplete multipart uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    # Handle versioned objects
    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_expiration {
      noncurrent_days = 60
    }
  }

  rule {
    id     = "backup_lifecycle"
    status = "Enabled"

    filter {
      prefix = "backups/"
    }

    # Shorter retention for backups
    expiration {
      days = 30
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }

  rule {
    id     = "deployment_records_lifecycle"
    status = "Enabled"

    filter {
      prefix = "deployments/"
    }

    # Keep deployment records longer for audit
    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    expiration {
      days = 365
    }
  }
}

# S3 bucket notification for monitoring (optional)
resource "aws_s3_bucket_notification" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  eventbridge = true
}

# IAM role for GitHub Actions OIDC
resource "aws_iam_role" "github_actions" {
  name = "${var.project_name}-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-github-actions-role"
    Environment = var.environment
  }
}

# IAM policy for artifact management
resource "aws_iam_policy" "artifact_management" {
  name        = "${var.project_name}-artifact-management"
  description = "Policy for managing build artifacts in S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:ListBucket",
          "s3:ListBucketVersions"
        ]
        Resource = [
          aws_s3_bucket.artifacts.arn,
          var.bucket_arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:DeleteObjectVersion",
          "s3:GetObjectMetadata",
          "s3:PutObjectMetadata"
        ]
        Resource = [
          "${aws_s3_bucket.artifacts.arn}/*",
          "${var.bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.s3_artifacts.arn
      }
    ]
  })
}

# Attach artifact management policy to GitHub Actions role
resource "aws_iam_role_policy_attachment" "github_actions_artifacts" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.artifact_management.arn
}

# IAM policy for deployment bucket access (separate buckets)
resource "aws_iam_policy" "deployment_management" {
  name        = "${var.project_name}-deployment-management"
  description = "Policy for managing deployments to S3 buckets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:ListBucket",
          "s3:ListBucketVersions"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-staging-*",
          "arn:aws:s3:::${var.project_name}-production-*",
          "arn:aws:s3:::${var.project_name}-*-backups"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:PutObjectAcl"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-staging-*/*",
          "arn:aws:s3:::${var.project_name}-production-*/*",
          "arn:aws:s3:::${var.project_name}-*-backups/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "cloudfront:CreateInvalidation",
          "cloudfront:GetInvalidation",
          "cloudfront:ListInvalidations"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach deployment management policy to GitHub Actions role
resource "aws_iam_role_policy_attachment" "github_actions_deployment" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.deployment_management.arn
}

# CloudWatch log group for monitoring S3 access
resource "aws_cloudwatch_log_group" "s3_access" {
  name              = "/aws/s3/${aws_s3_bucket.artifacts.id}"
  retention_in_days = 30

  tags = {
    Name        = "${var.project_name}-s3-access-logs"
    Environment = var.environment
  }
}

# EventBridge rule for S3 artifact uploads (optional monitoring)
resource "aws_cloudwatch_event_rule" "artifact_uploaded" {
  name        = "${var.project_name}-artifact-uploaded"
  description = "Trigger when new artifact is uploaded"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = [aws_s3_bucket.artifacts.id]
      }
      object = {
        key = [{
          prefix = "artifacts/"
        }]
      }
    }
  })

  tags = {
    Name        = "${var.project_name}-artifact-uploaded"
    Environment = var.environment
  }
}


resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1" # GitHub's root cert thumbprint
  ]

  tags = {
    Name = "GitHub Actions OIDC Provider"
  }
}