#!/usr/bin/env bash
set -eo pipefail

# Default values
REPO_URL=${REPO_URL:-"https://github.com/Nevelin-W/portfolio.git"}
REPO_BRANCH=${REPO_BRANCH:-"minimalistic_v1"}
PROJECT_PATH=${PROJECT_PATH:-"myportfolio"}
BUILD_TYPE=${BUILD_TYPE:-"web"}
OUTPUT_DIR=${OUTPUT_DIR:-"build/web"}
S3_BUCKET=${S3_BUCKET}
CLOUDFRONT_DISTRIBUTION_ID=${CLOUDFRONT_DISTRIBUTION_ID}
AWS_REGION=${AWS_REGION:-"us-east-1"}
DRY_RUN=${DRY_RUN:-false}
REPO_NAME=${REPO_NAME:-"portfolio"}
VERBOSE=${VERBOSE:-false}

# Configure logging
log() {
  local level=$1
  shift
  if [[ $VERBOSE == "true" ]] || [[ $level != "DEBUG" ]]; then
    echo "[$level] $@"
  fi
}

error() { log "ERROR" "$@"; }
info() { log "INFO" "$@"; }
debug() { log "DEBUG" "$@"; }
success() { log "SUCCESS" "$@"; }

# Function to check if AWS credentials are available
check_aws_credentials() {
  info "Checking AWS credentials..."
  if ! aws sts get-caller-identity &>/dev/null; then
    error "AWS credentials are not configured properly"
    error "Please set AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and optionally AWS_SESSION_TOKEN"
    exit 1
  fi
  success "AWS credentials validated"
}

# Clone the repository
clone_repo() {
  info "Cloning repository: $REPO_URL branch: $REPO_BRANCH"
  local clone_dir="/app/$REPO_NAME"
  # Remove if exists
  if [ -d "$clone_dir" ]; then
    rm -rf "$clone_dir"
  fi
  
  git clone --branch "$REPO_BRANCH" --single-branch "$REPO_URL" "$clone_dir"
  success "Repository cloned successfully"
}

# Build Flutter project
build_project() {
  local project_dir="/app/$REPO_NAME/$PROJECT_PATH"
  info "Building Flutter project at $project_dir"
  
  cd "$project_dir"
  
  # Install dependencies
  info "Installing dependencies..."
  if [ "$VERBOSE" == "true" ]; then
    flutter pub get
  else
    flutter pub get > /dev/null 2>&1
  fi
  
  # Build for target platform
  info "Building Flutter $BUILD_TYPE..."
  if [ "$VERBOSE" == "true" ]; then
    flutter build "$BUILD_TYPE" --release
  else
    flutter build "$BUILD_TYPE" --release > /dev/null 2>&1
  fi
  
  success "Flutter build completed successfully"
}

# Deploy to S3
deploy_to_s3() {
  info "Starting deployment to S3 bucket: $S3_BUCKET"
  
  # Check if the bucket exists
  if ! aws s3api head-bucket --bucket "$S3_BUCKET" --region "$AWS_REGION" 2>/dev/null; then
    error "Bucket $S3_BUCKET does not exist or you don't have access to it"
    exit 1
  fi
  
  local build_dir="/app/$REPO_NAME/$PROJECT_PATH/$OUTPUT_DIR"
  
  # Check if build directory exists
  if [ ! -d "$build_dir" ]; then
    error "Build directory not found: $build_dir"
    exit 1
  fi
  
  # Empty the bucket if necessary
  info "Emptying bucket $S3_BUCKET..."
  if [ "$DRY_RUN" == "true" ]; then
    info "[DRY RUN] Would empty bucket $S3_BUCKET"
  else
    if [ "$VERBOSE" == "true" ]; then
      aws s3 rm "s3://$S3_BUCKET/" --recursive --region "$AWS_REGION"
    else
      aws s3 rm "s3://$S3_BUCKET/" --recursive --region "$AWS_REGION" > /dev/null 2>&1
    fi
  fi
  
  # Upload build files
  info "Uploading build files to S3..."
  if [ "$DRY_RUN" == "true" ]; then
    info "[DRY RUN] Would upload files from $build_dir to s3://$S3_BUCKET/"
  else
    aws s3 cp "$build_dir" "s3://$S3_BUCKET/" --recursive --region "$AWS_REGION" $([ "$VERBOSE" == "true" ] || echo "> /dev/null 2>&1")
    success "Files uploaded successfully to S3"
  fi
}

# Invalidate CloudFront cache
invalidate_cloudfront() {
  if [ -z "$CLOUDFRONT_DISTRIBUTION_ID" ]; then
    info "No CloudFront distribution ID provided, skipping invalidation"
    return
  fi
  
  info "Invalidating CloudFront cache for distribution: $CLOUDFRONT_DISTRIBUTION_ID"
  if [ "$DRY_RUN" == "true" ]; then
    info "[DRY RUN] Would invalidate CloudFront cache for paths: /*"
  else
    aws cloudfront create-invalidation \
      --distribution-id "$CLOUDFRONT_DISTRIBUTION_ID" \
      --paths "/*" \
      --region "$AWS_REGION" \
      $([ "$VERBOSE" == "true" ] || echo "> /dev/null 2>&1")
    success "CloudFront cache invalidated successfully"
  fi
}

# Main function
main() {
  info "Starting deployment process"
  
  # Validate required parameters
  if [ -z "$S3_BUCKET" ]; then
    error "S3_BUCKET environment variable is required"
    exit 1
  fi
  
  # Check AWS credentials
  check_aws_credentials
  
  # Main workflow
  clone_repo
  build_project
  deploy_to_s3
  invalidate_cloudfront
  
  success "Deployment completed successfully!"
}

# Execute main function
main "$@"
