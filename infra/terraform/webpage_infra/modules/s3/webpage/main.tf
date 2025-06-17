resource "aws_s3_bucket" "s3_bucket_01" {
  bucket        = var.bucket_name
  force_destroy = var.environment == "dev" ? true : false

  tags = {
    ManagedByTf = "Yes"
    Environment = upper(var.environment)
  }
}

resource "aws_s3_bucket_public_access_block" "s3_public_access_block_01" {
  bucket                  = aws_s3_bucket.s3_bucket_01.id
  block_public_acls       = var.environment == "dev" ? true : false
  block_public_policy     = var.environment == "dev" ? true : false
  ignore_public_acls      = var.environment == "dev" ? true : false
  restrict_public_buckets = var.environment == "dev" ? true : false
}

# This policy will be applied after the CloudFront module creates the OAC
resource "aws_s3_bucket_policy" "s3_bucket_policy_01" {
  bucket = aws_s3_bucket.s3_bucket_01.id
  policy = var.bucket_policy
}

# Enable website hosting configuration
resource "aws_s3_bucket_website_configuration" "website_config_01" {
  bucket = aws_s3_bucket.s3_bucket_01.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}
