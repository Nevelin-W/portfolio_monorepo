#!/usr/bin/env bash
set -eo pipefail

# Default values
S3_BUCKET=${S3_BUCKET}
CLOUDFRONT_DISTRIBUTION_ID=${CLOUDFRONT_DISTRIBUTION_ID}
AWS_REGION=${AWS_REGION}
DRY_RUN=${DRY_RUN:-false}
VERBOSE=${VERBOSE:-false}

# Artifact configuration
ARTIFACT_BUCKET=${ARTIFACT_BUCKET}
ARTIFACT_PREFIX=${ARTIFACT_PREFIX}
ARTIFACT_VERSION=${ARTIFACT_VERSION}  # Can be specific version or "latest"
ARTIFACT_NAME=${ARTIFACT_NAME}        # Optional: specific artifact name

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

# Check AWS credentials
check_aws_credentials() {
  info "Checking AWS credentials..."
  if ! aws sts get-caller-identity &>/dev/null; then
    error "AWS credentials are not configured properly"
    exit 1
  fi
  success "AWS credentials validated"
}

# Find latest artifact if version not specified
find_latest_artifact() {
  if [ -n "$ARTIFACT_NAME" ]; then
    echo "$ARTIFACT_NAME"
    return
  fi
  
  if [ "$ARTIFACT_VERSION" == "latest" ] || [ -z "$ARTIFACT_VERSION" ]; then
    info "Finding latest artifact..."
    local latest_artifact=$(aws s3 ls "s3://$ARTIFACT_BUCKET/$ARTIFACT_PREFIX/" | \
      grep "portfolio-.*\.tar\.gz" | \
      sort -k4 | \
      tail -n1 | \
      awk '{print $4}')
    
    if [ -z "$latest_artifact" ]; then
      error "No artifacts found in s3://$ARTIFACT_BUCKET/$ARTIFACT_PREFIX/"
      exit 1
    fi
    
    info "Latest artifact: $latest_artifact"
    echo "$latest_artifact"
  else
    echo "portfolio-$ARTIFACT_VERSION.tar.gz"
  fi
}

# Download and extract artifact
download_artifact() {
  local artifact_name="$1"
  local artifact_path="/tmp/$artifact_name"
  local extract_dir="/tmp/artifact_extract"
  
  info "Downloading artifact: $artifact_name"
  
  # Download from S3
  aws s3 cp "s3://$ARTIFACT_BUCKET/$ARTIFACT_PREFIX/$artifact_name" "$artifact_path"
  
  # Extract artifact
  [ -d "$extract_dir" ] && rm -rf "$extract_dir"
  mkdir -p "$extract_dir"
  
  info "Extracting artifact..."
  cd "$extract_dir"
  tar -xzf "$artifact_path"
  
  # Verify build metadata exists
  if [ -f "build-metadata.json" ]; then
    info "Build metadata found:"
    if [ "$VERBOSE" == "true" ]; then
      cat build-metadata.json | jq . 2>/dev/null || cat build-metadata.json
    else
      local version=$(cat build-metadata.json | jq -r '.version' 2>/dev/null || echo "unknown")
      local build_date=$(cat build-metadata.json | jq -r '.build_date' 2>/dev/null || echo "unknown")
      info "  Version: $version"
      info "  Build Date: $build_date"
    fi
  fi
  
  success "Artifact downloaded and extracted to $extract_dir"
  echo "$extract_dir"
}

# Deploy to S3
deploy_to_s3() {
  local build_dir="$1"
  
  info "Starting deployment to S3 bucket: $S3_BUCKET"
  
  # Verify bucket exists
  if ! aws s3api head-bucket --bucket "$S3_BUCKET" --region "$AWS_REGION" 2>/dev/null; then
    error "Bucket $S3_BUCKET does not exist or access denied"
    exit 1
  fi

  # Verify build directory
  [ ! -d "$build_dir" ] && { error "Build directory not found: $build_dir"; exit 1; }

  # Backup current deployment (optional)
  backup_current_deployment

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

  info "Uploading build files to S3..."
  if [ "$DRY_RUN" == "true" ]; then
    info "[DRY RUN] Would upload files from $build_dir to s3://$S3_BUCKET/"
  else
    if [ "$VERBOSE" == "true" ]; then
      aws s3 cp "$build_dir" "s3://$S3_BUCKET/" --recursive --region "$AWS_REGION"
    else
      aws s3 cp "$build_dir" "s3://$S3_BUCKET/" --recursive --region "$AWS_REGION" > /dev/null 2>&1
    fi
    success "Files uploaded successfully to S3"
  fi
}

# Backup current deployment
backup_current_deployment() {
  local backup_bucket="${S3_BUCKET}-backups"
  local backup_key="backups/$(date +%Y%m%d-%H%M%S)"
  
  info "Creating backup of current deployment..."
  
  # Check if backup bucket exists, create if not
  if ! aws s3api head-bucket --bucket "$backup_bucket" 2>/dev/null; then
    info "Backup bucket $backup_bucket not found, skipping backup"
    return
  fi
  
  if [ "$DRY_RUN" == "true" ]; then
    info "[DRY RUN] Would backup current deployment to s3://$backup_bucket/$backup_key/"
  else
    # Copy current deployment to backup
    aws s3 sync "s3://$S3_BUCKET/" "s3://$backup_bucket/$backup_key/" \
      --region "$AWS_REGION" > /dev/null 2>&1 || info "Backup failed (non-critical)"
    info "Backup created at s3://$backup_bucket/$backup_key/"
  fi
}

# CloudFront invalidation
invalidate_cloudfront() {
  [ -z "$CLOUDFRONT_DISTRIBUTION_ID" ] && { info "No CloudFront distribution ID provided, skipping"; return; }

  info "Invalidating CloudFront cache for distribution: $CLOUDFRONT_DISTRIBUTION_ID"
  if [ "$DRY_RUN" == "true" ]; then
    info "[DRY RUN] Would invalidate CloudFront cache for paths: /*"
  else
    if [ "$VERBOSE" == "true" ]; then
      aws cloudfront create-invalidation \
        --distribution-id "$CLOUDFRONT_DISTRIBUTION_ID" \
        --paths "/*" \
        --region "$AWS_REGION"
    else
      aws cloudfront create-invalidation \
        --distribution-id "$CLOUDFRONT_DISTRIBUTION_ID" \
        --paths "/*" \
        --region "$AWS_REGION" > /dev/null 2>&1
    fi
    success "CloudFront cache invalidated successfully"
  fi
}

# Rollback deployment
rollback_deployment() {
  local backup_key="$1"
  if [ -z "$backup_key" ]; then
    error "Backup key required for rollback"
    exit 1
  fi
  
  local backup_bucket="${S3_BUCKET}-backups"
  
  info "Rolling back deployment from backup: $backup_key"
  
  if [ "$DRY_RUN" == "true" ]; then
    info "[DRY RUN] Would rollback from s3://$backup_bucket/$backup_key/"
  else
    # Empty current bucket
    aws s3 rm "s3://$S3_BUCKET/" --recursive --region "$AWS_REGION" > /dev/null 2>&1
    
    # Restore from backup
    aws s3 sync "s3://$backup_bucket/$backup_key/" "s3://$S3_BUCKET/" \
      --region "$AWS_REGION"
    
    success "Rollback completed successfully"
  fi
}

# Main deployment function
main() {
  info "Starting deployment process"
  
  # Validate required parameters
  [ -z "$S3_BUCKET" ] && { error "S3_BUCKET environment variable is required"; exit 1; }
  [ -z "$ARTIFACT_BUCKET" ] && { error "ARTIFACT_BUCKET environment variable is required"; exit 1; }
  
  check_aws_credentials
  
  # Find and download artifact
  local artifact_name=$(find_latest_artifact)
  local build_dir=$(download_artifact "$artifact_name")
  
  # Deploy
  deploy_to_s3 "$build_dir"
  invalidate_cloudfront
  
  # Cleanup
  rm -rf "$build_dir" "/tmp/portfolio-*.tar.gz"
  
  success "Deployment completed successfully!"
  info "Deployed artifact: $artifact_name"
}

# Handle command line arguments
case "${1:-deploy}" in
  "deploy")
    main
    ;;
  "rollback")
    [ -z "$2" ] && { error "Rollback requires backup key as second argument"; exit 1; }
    check_aws_credentials
    rollback_deployment "$2"
    ;;
  "list-artifacts")
    check_aws_credentials
    info "Available artifacts:"
    aws s3 ls "s3://$ARTIFACT_BUCKET/$ARTIFACT_PREFIX/" | grep "portfolio-.*\.tar\.gz" | sort -k4
    ;;
  *)
    echo "Usage: $0 [deploy|rollback <backup-key>|list-artifacts]"
    exit 1
    ;;
esac