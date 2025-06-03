#!/usr/bin/env bash
set -eo pipefail

# Default values
S3_BUCKET=${S3_BUCKET}
CLOUDFRONT_DISTRIBUTION_ID=${CLOUDFRONT_DISTRIBUTION_ID}
AWS_REGION=${AWS_REGION:-"us-east-1"}
DRY_RUN=${DRY_RUN:-false}
VERBOSE=${VERBOSE:-false}

# Artifact configuration
ARTIFACT_BUCKET=${ARTIFACT_BUCKET}
ARTIFACT_PREFIX=${ARTIFACT_PREFIX:-"artifacts"}
ARTIFACT_VERSION=${ARTIFACT_VERSION}  # Can be specific version or "latest"

# GitHub Actions output support
GITHUB_OUTPUT=${GITHUB_OUTPUT}

# Configure logging
log() {
  local level=$1
  shift
  if [[ $VERBOSE == "true" ]] || [[ $level != "DEBUG" ]]; then
    echo "[$level] $(date '+%Y-%m-%d %H:%M:%S') - $@" >&2
  fi
}

error() { log "ERROR" "$@"; }
info() { log "INFO" "$@"; }
debug() { log "DEBUG" "$@"; }
success() { log "SUCCESS" "$@"; }

# Output to GitHub Actions
output_github() {
  local key="$1"
  local value="$2"
  if [ -n "$GITHUB_OUTPUT" ]; then
    {
      echo "${key}=${value}" >> "$GITHUB_OUTPUT"
    } 2>/dev/null || {
      debug "Failed to write to GITHUB_OUTPUT: ${key}=${value}"
    }
  fi
}

# Check AWS credentials
check_aws_credentials() {
  info "Checking AWS credentials..."
  if ! aws sts get-caller-identity &>/dev/null; then
    error "AWS credentials are not configured properly"
    exit 1
  fi
  
  local caller_identity=$(aws sts get-caller-identity 2>/dev/null)
  local account_id=$(echo "$caller_identity" | jq -r '.Account' 2>/dev/null || echo "unknown")
  local user_arn=$(echo "$caller_identity" | jq -r '.Arn' 2>/dev/null || echo "unknown")
  
  success "AWS credentials validated"
  debug "Account ID: $account_id"
  debug "User ARN: $user_arn"
}

# Validate required parameters
validate_parameters() {
  local errors=()
  
  [ -z "$S3_BUCKET" ] && errors+=("S3_BUCKET")
  [ -z "$ARTIFACT_BUCKET" ] && errors+=("ARTIFACT_BUCKET")
  [ -z "$ARTIFACT_VERSION" ] && errors+=("ARTIFACT_VERSION")
  [ -z "$CLOUDFRONT_DISTRIBUTION_ID" ] && errors+=("CLOUDFRONT_DISTRIBUTION_ID")
  
  if [ ${#errors[@]} -gt 0 ]; then
    error "Required environment variables are missing:"
    for var in "${errors[@]}"; do
      error "  - $var"
    done
    exit 1
  fi
  
  # Validate S3 bucket name format
  if [[ ! "$S3_BUCKET" =~ ^[a-z0-9][a-z0-9.-]*[a-z0-9]$ ]]; then
    error "Invalid S3 bucket name format: $S3_BUCKET"
    exit 1
  fi
}

# Find latest artifact or use specified version
find_latest_artifact() {
  if [ "$ARTIFACT_VERSION" == "latest" ]; then
    info "Finding latest artifact..."
    local latest_artifact=$(aws s3 ls "s3://$ARTIFACT_BUCKET/$ARTIFACT_PREFIX/" --recursive | \
      grep "portfolio-.*\.tar\.gz" | \
      sort -k1,2 | \
      tail -1 | \
      awk '{print $4}' | \
      sed "s|^$ARTIFACT_PREFIX/||")
    
    if [ -z "$latest_artifact" ]; then
      error "No portfolio artifacts found in s3://$ARTIFACT_BUCKET/$ARTIFACT_PREFIX/"
      exit 1
    fi
    
    info "Latest artifact found: $latest_artifact"
    echo "$latest_artifact"
  else
    # ARTIFACT_VERSION is already the full filename
    if [[ "$ARTIFACT_VERSION" == *.tar.gz ]]; then
      info "Using provided artifact filename: $ARTIFACT_VERSION"
      echo "$ARTIFACT_VERSION"
    else
      # Legacy support: construct filename from version
      local versioned_artifact="portfolio-$ARTIFACT_VERSION.tar.gz"
      info "Using versioned artifact: $versioned_artifact"
      echo "$versioned_artifact"
    fi
  fi
}

# Verify artifact exists
verify_artifact_exists() {
  local artifact_name="$1"
  local artifact_key="$ARTIFACT_PREFIX/$artifact_name"
  
  info "Verifying artifact exists: s3://$ARTIFACT_BUCKET/$artifact_key"
  
  if ! aws s3api head-object --bucket "$ARTIFACT_BUCKET" --key "$artifact_key" &>/dev/null; then
    error "Artifact not found: s3://$ARTIFACT_BUCKET/$artifact_key"
    info "Available artifacts:"
    aws s3 ls "s3://$ARTIFACT_BUCKET/$ARTIFACT_PREFIX/" 2>/dev/null | grep "portfolio-.*\.tar\.gz" || info "No portfolio artifacts found"
    exit 1
  fi
  
  # Get artifact metadata
  local artifact_size=$(aws s3api head-object --bucket "$ARTIFACT_BUCKET" --key "$artifact_key" \
    --query 'ContentLength' --output text 2>/dev/null)
  local artifact_modified=$(aws s3api head-object --bucket "$ARTIFACT_BUCKET" --key "$artifact_key" \
    --query 'LastModified' --output text 2>/dev/null)
  
  info "Artifact verified:"
  info "  Size: $(numfmt --to=iec --suffix=B $artifact_size 2>/dev/null || echo "$artifact_size bytes")"
  info "  Modified: $artifact_modified"
  
  success "Artifact verification completed"
}

# Download and extract artifact
download_artifact() {
  local artifact_name="$1"
  local artifact_path="/tmp/$artifact_name"
  local extract_dir="/tmp/artifact_extract"
  
  info "Downloading artifact: $artifact_name"
  
  # Clean up any existing files
  rm -rf "$artifact_path" "$extract_dir"
  
  # Download from S3 with progress if verbose
  if [ "$VERBOSE" == "true" ]; then
    aws s3 cp "s3://$ARTIFACT_BUCKET/$ARTIFACT_PREFIX/$artifact_name" "$artifact_path"
  else
    aws s3 cp "s3://$ARTIFACT_BUCKET/$ARTIFACT_PREFIX/$artifact_name" "$artifact_path" > /dev/null 2>&1
  fi
  
  # Verify download
  if [ ! -f "$artifact_path" ]; then
    error "Failed to download artifact: $artifact_path"
    exit 1
  fi
  
  # Extract artifact
  mkdir -p "$extract_dir"
  info "Extracting artifact..."
  cd "$extract_dir"
  
  if [ "$VERBOSE" == "true" ]; then
    tar -xzf "$artifact_path"
  else
    tar -xzf "$artifact_path" 2>/dev/null
  fi
  
  # Verify extraction
  if [ ! "$(ls -A "$extract_dir")" ]; then
    error "Artifact extraction failed or directory is empty"
    exit 1
  fi
  
  # Display build metadata if available
  if [ -f "build-metadata.json" ]; then
    info "Build metadata found:"
    if command -v jq &>/dev/null && [ "$VERBOSE" == "true" ]; then
      cat build-metadata.json | jq . 2>/dev/null || cat build-metadata.json
    else
      local version=$(cat build-metadata.json | jq -r '.version' 2>/dev/null || echo "unknown")
      local build_date=$(cat build-metadata.json | jq -r '.build_date' 2>/dev/null || echo "unknown")
      local git_commit=$(cat build-metadata.json | jq -r '.git.commit' 2>/dev/null || echo "unknown")
      info "  Version: $version"
      info "  Build Date: $build_date"
      info "  Git Commit: ${git_commit:0:8}"
      
      # Output metadata to GitHub Actions
      output_github "BUILD_VERSION" "$version"
      output_github "BUILD_DATE" "$build_date"
      output_github "GIT_COMMIT" "$git_commit"
    fi
  fi
  
  success "Artifact downloaded and extracted to $extract_dir"
  echo "$extract_dir"
}

# Deploy to S3
deploy_to_s3() {
  local build_dir="$1"
  
  info "Starting deployment to S3 bucket: $S3_BUCKET"
  
  # Verify bucket exists and is accessible
  if ! aws s3api head-bucket --bucket "$S3_BUCKET" --region "$AWS_REGION" 2>/dev/null; then
    error "Bucket $S3_BUCKET does not exist or access denied in region $AWS_REGION"
    info "Available buckets:"
    aws s3 ls 2>/dev/null || info "Unable to list buckets"
    exit 1
  fi

  # Verify build directory
  [ ! -d "$build_dir" ] && { error "Build directory not found: $build_dir"; exit 1; }
  
  # Count files to be uploaded
  local file_count=$(find "$build_dir" -type f | wc -l)
  info "Found $file_count files to deploy"

  # Backup current deployment (optional)
  backup_current_deployment

  # Sync files instead of deleting and uploading (safer)
  info "Synchronizing files to S3..."
  if [ "$DRY_RUN" == "true" ]; then
    info "[DRY RUN] Would synchronize files from $build_dir to s3://$S3_BUCKET/"
    if [ "$VERBOSE" == "true" ]; then
      aws s3 sync "$build_dir" "s3://$S3_BUCKET/" --dryrun --delete --region "$AWS_REGION"
    fi
  else
    local sync_cmd="aws s3 sync \"$build_dir\" \"s3://$S3_BUCKET/\" --delete --region \"$AWS_REGION\""
    
    if [ "$VERBOSE" == "true" ]; then
      aws s3 sync "$build_dir" "s3://$S3_BUCKET/" --delete --region "$AWS_REGION"
    else
      aws s3 sync "$build_dir" "s3://$S3_BUCKET/" --delete --region "$AWS_REGION" > /dev/null 2>&1
    fi
    
    success "Files synchronized successfully to S3"
    
    # Verify deployment
    local uploaded_count=$(aws s3 ls "s3://$S3_BUCKET/" --recursive | wc -l)
    info "Verification: $uploaded_count files now in S3 bucket"
  fi
  
  # Output deployment info
  output_github "DEPLOYMENT_S3_BUCKET" "$S3_BUCKET"
  output_github "DEPLOYMENT_FILE_COUNT" "$file_count"
}

# Backup current deployment
backup_current_deployment() {
  local backup_bucket="${S3_BUCKET}-backups"
  local backup_key="backups/$(date +%Y%m%d-%H%M%S)"
  
  info "Checking for backup configuration..."
  
  # Check if backup bucket exists
  if ! aws s3api head-bucket --bucket "$backup_bucket" 2>/dev/null; then
    debug "Backup bucket $backup_bucket not found, skipping backup"
    return
  fi
  
  info "Creating backup of current deployment..."
  
  if [ "$DRY_RUN" == "true" ]; then
    info "[DRY RUN] Would backup current deployment to s3://$backup_bucket/$backup_key/"
  else
    # Check if source bucket has content
    local current_files=$(aws s3 ls "s3://$S3_BUCKET/" --recursive 2>/dev/null | wc -l)
    if [ "$current_files" -eq 0 ]; then
      info "No existing files to backup"
      return
    fi
    
    # Copy current deployment to backup
    if aws s3 sync "s3://$S3_BUCKET/" "s3://$backup_bucket/$backup_key/" \
      --region "$AWS_REGION" > /dev/null 2>&1; then
      success "Backup created at s3://$backup_bucket/$backup_key/"
      output_github "BACKUP_LOCATION" "s3://$backup_bucket/$backup_key/"
    else
      info "Backup failed (non-critical, continuing with deployment)"
    fi
  fi
}

# CloudFront invalidation
invalidate_cloudfront() {
  info "Invalidating CloudFront cache for distribution: $CLOUDFRONT_DISTRIBUTION_ID"
  
  if [ "$DRY_RUN" == "true" ]; then
    info "[DRY RUN] Would invalidate CloudFront cache for paths: /*"
  else
    local invalidation_output
    if [ "$VERBOSE" == "true" ]; then
      invalidation_output=$(aws cloudfront create-invalidation \
        --distribution-id "$CLOUDFRONT_DISTRIBUTION_ID" \
        --paths "/*" 2>/dev/null)
    else
      invalidation_output=$(aws cloudfront create-invalidation \
        --distribution-id "$CLOUDFRONT_DISTRIBUTION_ID" \
        --paths "/*" 2>/dev/null)
    fi
    
    if [ $? -eq 0 ]; then
      local invalidation_id=$(echo "$invalidation_output" | jq -r '.Invalidation.Id' 2>/dev/null)
      success "CloudFront cache invalidation created: $invalidation_id"
      output_github "CLOUDFRONT_INVALIDATION_ID" "$invalidation_id"
    else
      error "CloudFront invalidation failed"
      exit 1
    fi
  fi
}

# Get CloudFront domain name
get_cloudfront_domain() {
  local domain_name=$(aws cloudfront get-distribution \
    --id "$CLOUDFRONT_DISTRIBUTION_ID" \
    --query 'Distribution.DomainName' \
    --output text 2>/dev/null)
  
  if [ -n "$domain_name" ] && [ "$domain_name" != "None" ]; then
    output_github "CLOUDFRONT_DOMAIN" "$domain_name"
    output_github "DEPLOYMENT_URL" "https://$domain_name"
  fi
}

# List recent artifacts
list_artifacts() {
  if [ -z "$ARTIFACT_BUCKET" ]; then
    info "No artifact bucket specified"
    return
  fi
  
  info "Recent artifacts in s3://$ARTIFACT_BUCKET/$ARTIFACT_PREFIX/:"
  if aws s3 ls "s3://$ARTIFACT_BUCKET/$ARTIFACT_PREFIX/" --recursive > /dev/null 2>&1; then
    aws s3 ls "s3://$ARTIFACT_BUCKET/$ARTIFACT_PREFIX/" --recursive | \
      grep "portfolio-.*\.tar\.gz" | \
      sort -k1,2 | \
      tail -10
  else
    info "No artifacts found or unable to list artifacts"
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
  
  # Verify backup exists
  if ! aws s3 ls "s3://$backup_bucket/$backup_key/" > /dev/null 2>&1; then
    error "Backup not found: s3://$backup_bucket/$backup_key/"
    exit 1
  fi
  
  if [ "$DRY_RUN" == "true" ]; then
    info "[DRY RUN] Would rollback from s3://$backup_bucket/$backup_key/"
  else
    # Sync from backup (this will replace current files)
    aws s3 sync "s3://$backup_bucket/$backup_key/" "s3://$S3_BUCKET/" \
      --delete --region "$AWS_REGION"
    
    success "Rollback completed successfully"
    output_github "ROLLBACK_FROM" "s3://$backup_bucket/$backup_key/"
    
    # Invalidate CloudFront if configured
    invalidate_cloudfront
  fi
}

# Main deployment function
main() {
  info "Starting deployment process"
  info "Configuration:"
  info "  S3 Bucket: $S3_BUCKET"
  info "  CloudFront Distribution: ${CLOUDFRONT_DISTRIBUTION_ID:-"None"}"
  info "  Artifact Bucket: $ARTIFACT_BUCKET"
  info "  Artifact Version: ${ARTIFACT_VERSION:-"latest"}"
  info "  AWS Region: $AWS_REGION"
  info "  Dry Run: $DRY_RUN"
  info "  Verbose: $VERBOSE"
  
  # Validate and setup
  validate_parameters
  check_aws_credentials
  
  # Find and verify artifact
  local artifact_name=$(find_latest_artifact)
  verify_artifact_exists "$artifact_name"
  
  # Download and extract
  local build_dir=$(download_artifact "$artifact_name")
  
  # Deploy
  deploy_to_s3 "$build_dir"
  invalidate_cloudfront
  get_cloudfront_domain
  
  # Output final results
  output_github "DEPLOYED_ARTIFACT" "$artifact_name"
  output_github "DEPLOYMENT_STATUS" "success"
  
  # Default deployment URL if CloudFront not configured
  if [ -z "$CLOUDFRONT_DISTRIBUTION_ID" ]; then
    local s3_website_url="https://$S3_BUCKET.s3-website-$AWS_REGION.amazonaws.com"
    output_github "DEPLOYMENT_URL" "$s3_website_url"
  fi
  
  # Cleanup
  rm -rf "$build_dir" "/tmp/portfolio-*.tar.gz"
  
  success "Deployment completed successfully!"
  info "Deployed artifact: $artifact_name"
  info "S3 Bucket: $S3_BUCKET"
  [ -n "$CLOUDFRONT_DISTRIBUTION_ID" ] && info "CloudFront Distribution: $CLOUDFRONT_DISTRIBUTION_ID"
}

# Handle command line arguments
case "${1:-deploy}" in
  "deploy")
    main
    ;;
  "rollback")
    [ -z "$2" ] && { error "Rollback requires backup key as second argument"; exit 1; }
    validate_parameters
    check_aws_credentials
    rollback_deployment "$2"
    ;;
  "list-artifacts")
    check_aws_credentials
    list_artifacts
    ;;
  "verify")
    # Verify deployment without deploying
    validate_parameters
    check_aws_credentials
    local artifact_name=$(find_latest_artifact)
    verify_artifact_exists "$artifact_name"
    info "Verification completed successfully"
    ;;
  *)
    echo "Usage: $0 [deploy|rollback <backup-key>|list-artifacts|verify]"
    echo ""
    echo "Commands:"
    echo "  deploy           Deploy artifact to S3 (default)"
    echo "  rollback <key>   Rollback to previous deployment"
    echo "  list-artifacts   List available artifacts"
    echo "  verify           Verify deployment configuration"
    exit 1
    ;;
esac
