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
ARTIFACT_VERSION=${ARTIFACT_VERSION}

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
}
# Find latest artifact or use specified version
artifact_name_handling() {
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

# Download and extract artifact - FIXED VERSION
download_artifact() {
  local artifact_name="$1"
  local artifact_path="/tmp/$artifact_name"
  local extract_dir="/tmp/artifact_extract"
  
  info "Downloading artifact: $artifact_name"
  
  # Clean up any existing files
  rm -rf "$artifact_path" "$extract_dir"
  
  # Download from S3 with proper output suppression
  if [ "$VERBOSE" == "true" ]; then
    aws s3 cp "s3://$ARTIFACT_BUCKET/$ARTIFACT_PREFIX/$artifact_name" "$artifact_path" >&2
  else
    # Completely suppress AWS CLI output to prevent contamination
    aws s3 cp "s3://$ARTIFACT_BUCKET/$ARTIFACT_PREFIX/$artifact_name" "$artifact_path" --no-progress >/dev/null 2>&1
  fi
  
  # Verify download
  if [ ! -f "$artifact_path" ]; then
    error "Failed to download artifact: $artifact_path"
    exit 1
  fi
  
  # Create extract directory
  info "Creating extraction directory: $extract_dir"
  if ! mkdir -p "$extract_dir"; then
    error "Failed to create extraction directory: $extract_dir"
    exit 1
  fi
  
  # Verify directory was created
  if [ ! -d "$extract_dir" ]; then
    error "Extraction directory was not created: $extract_dir"
    exit 1
  fi
  
  # Test write permissions
  local test_file="$extract_dir/test_write"
  if ! touch "$test_file" 2>/dev/null || [ ! -f "$test_file" ]; then
    error "No write permissions in extraction directory: $extract_dir"
    exit 1
  fi
  rm -f "$test_file"
  
  # Extract artifact
  info "Extracting artifact to: $extract_dir"
  
  # Test tar file first
  if ! tar -tzf "$artifact_path" >/dev/null 2>&1; then
    error "Invalid or corrupted tar file: $artifact_path"
    exit 1
  fi
  
  # Extract with proper error handling
  if ! tar -xzf "$artifact_path" -C "$extract_dir" 2>/dev/null; then
    error "Failed to extract artifact"
    # Try with verbose output for debugging
    if [ "$VERBOSE" == "true" ]; then
      tar -xzf "$artifact_path" -C "$extract_dir"
    fi
    exit 1
  fi
  
  # Verify extraction worked
  if [ ! "$(ls -A "$extract_dir" 2>/dev/null)" ]; then
    error "Extraction failed or directory is empty: $extract_dir"
    exit 1
  fi
  
  # Check if files are in a subdirectory and move them up if needed
  local content_count=$(find "$extract_dir" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)
  if [ "$content_count" -eq 1 ]; then
    local single_item=$(find "$extract_dir" -mindepth 1 -maxdepth 1 2>/dev/null)
    if [ -d "$single_item" ]; then
      # If there's only one directory, move its contents up
      info "Moving contents from subdirectory to root level"
      local temp_dir="/tmp/artifact_temp_$$"
      mv "$single_item" "$temp_dir"
      rm -rf "$extract_dir"
      mv "$temp_dir" "$extract_dir"
    fi
  fi
  
  # Display build metadata if available
  if [ -f "$extract_dir/build-metadata.json" ]; then
    info "Build metadata found:"
    if command -v jq &>/dev/null && [ "$VERBOSE" == "true" ]; then
      cat "$extract_dir/build-metadata.json" | jq . 2>/dev/null || cat "$extract_dir/build-metadata.json"
    else
      local version=$(cat "$extract_dir/build-metadata.json" | jq -r '.version' 2>/dev/null || echo "unknown")
      local build_date=$(cat "$extract_dir/build-metadata.json" | jq -r '.build_date' 2>/dev/null || echo "unknown")  
      local git_commit=$(cat "$extract_dir/build-metadata.json" | jq -r '.git.commit' 2>/dev/null || echo "unknown")
      info "  Version: $version"
      info "  Build Date: $build_date"
      info "  Git Commit: ${git_commit:0:8}"
      
      # Output metadata to GitHub Actions
      output_github "BUILD_VERSION" "$version"
      output_github "BUILD_DATE" "$build_date"
      output_github "GIT_COMMIT" "$git_commit"
    fi
  fi
  
  success "Artifact extracted and ready for deployment"
  
  # CRITICAL FIX: Output directory path as the last line to stdout
  echo "$extract_dir"
  return 0
}

# Deploy to S3
deploy_to_s3() {
  local build_dir="$1"
  
  info "Starting deployment to S3 bucket: $S3_BUCKET"
  
  # Verify build directory exists and has content
  if [ ! -d "$build_dir" ]; then
    error "Build directory does not exist: $build_dir"
    exit 1
  fi
  
  # Verify bucket exists and is accessible
  if ! aws s3api head-bucket --bucket "$S3_BUCKET" --region "$AWS_REGION" 2>/dev/null; then
    error "Bucket $S3_BUCKET does not exist or access denied in region $AWS_REGION"
    exit 1
  fi

  # Count files to be uploaded - FIX: Use absolute path and proper error handling
  local file_count
  file_count=$(find "$build_dir" -type f 2>/dev/null | wc -l)
  
  if [ "$file_count" -eq 0 ]; then
    error "No files found in build directory: $build_dir"
    debug "Directory contents:"
    ls -la "$build_dir" 2>/dev/null || debug "Cannot list directory contents"
    exit 1
  fi
  
  info "Deploying $file_count files to S3"

  # Backup current deployment (optional)
  backup_current_deployment

  # Deploy files to S3
  info "Synchronizing files to S3..."
  
  if [ "$DRY_RUN" == "true" ]; then
    info "[DRY RUN] Would synchronize files from $build_dir to s3://$S3_BUCKET/"
    if [ "$VERBOSE" == "true" ]; then
      aws s3 sync "$build_dir" "s3://$S3_BUCKET/" --dryrun --delete --region "$AWS_REGION"
    fi
  else    
    if [ "$VERBOSE" == "true" ]; then
      aws s3 sync "$build_dir" "s3://$S3_BUCKET/" --delete --region "$AWS_REGION"
    else
      # Suppress progress output to prevent interference
      aws s3 sync "$build_dir" "s3://$S3_BUCKET/" --delete --region "$AWS_REGION" --no-progress >/dev/null 2>&1
    fi
    
    success "Files deployed successfully to S3"
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
      --region "$AWS_REGION" --no-progress >/dev/null 2>&1; then
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
    invalidation_output=$(aws cloudfront create-invalidation \
      --distribution-id "$CLOUDFRONT_DISTRIBUTION_ID" \
      --paths "/*" 2>/dev/null)
    
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

# Rollback deployment - FIXED VERSION
rollback_deployment() {
  local backup_key="$1"
  if [ -z "$backup_key" ]; then
    error "Backup key required for rollback"
    exit 1
  fi
  
  local backup_bucket="${S3_BUCKET}-backups"
  
  info "Rolling back deployment from backup: $backup_key"
  
  # Verify backup exists - FIXED: Added proper if statement
  if ! aws s3api head-object --bucket "$backup_bucket" --key "$backup_key" &>/dev/null; then
    error "Backup not found: s3://$backup_bucket/$backup_key/"
    exit 1
  fi
  
  if [ "$DRY_RUN" == "true" ]; then
    info "[DRY RUN] Would rollback from s3://$backup_bucket/$backup_key/"
  else
    # Sync from backup (this will replace current files)
    aws s3 sync "s3://$backup_bucket/$backup_key/" "s3://$S3_BUCKET/" \
      --delete --region "$AWS_REGION" --no-progress
    
    success "Rollback completed successfully"
    output_github "ROLLBACK_FROM" "s3://$backup_bucket/$backup_key/"
    
    # Invalidate CloudFront if configured
    invalidate_cloudfront
  fi
}

# Main deployment function - FIXED VERSION
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
  local artifact_name=$(artifact_name_handling)
  verify_artifact_exists "$artifact_name"
  
  # Download and extract - FIXED: Use temp file to avoid command substitution issues
  info "Downloading and extracting artifact..."
  local build_dir_file="/tmp/build_dir.txt"
  
  # Call function and save result to file to avoid stdout contamination
  if download_artifact "$artifact_name" > "$build_dir_file" 2>&1; then
    local build_dir=$(cat "$build_dir_file" 2>/dev/null | tail -1)
    rm -f "$build_dir_file"
    local download_exit_code=0
  else
    local download_exit_code=$?
    rm -f "$build_dir_file"
  fi
  
  # Check if download_artifact function succeeded
  if [ $download_exit_code -ne 0 ]; then
    error "download_artifact function failed with exit code: $download_exit_code"
    exit 1
  fi
  
  # Debug: Show what was captured
  debug "build_dir variable contains: '$build_dir'"
  
  # Verify build_dir was returned and exists
  if [ -z "$build_dir" ]; then
    error "download_artifact did not return a build directory path"
    debug "Checking for expected extraction directory: /tmp/artifact_extract"
    if [ -d "/tmp/artifact_extract" ]; then
      info "Found extraction directory, using it as fallback"
      build_dir="/tmp/artifact_extract"
    else
      error "No extraction directory found"
      debug "Contents of /tmp:"
      ls -la /tmp/ | grep -E "(artifact|portfolio)" || debug "No artifact-related directories found"
      exit 1
    fi
  fi
  
  # Trim any whitespace from build_dir
  build_dir=$(echo "$build_dir" | tr -d '[:space:]')
  
  if [ ! -d "$build_dir" ]; then
    error "Build directory does not exist: '$build_dir'"
    debug "Available directories in /tmp:"
    ls -la /tmp/ | grep artifact || debug "No artifact directories found"
    exit 1
  fi
  
  # Verify build directory has content
  local file_count=$(find "$build_dir" -type f 2>/dev/null | wc -l)
  if [ "$file_count" -eq 0 ]; then
    error "Build directory is empty: $build_dir"
    debug "Directory contents:"
    ls -la "$build_dir" 2>/dev/null || debug "Cannot list directory contents"
    exit 1
  fi
  
  info "Build directory verified: $build_dir ($file_count files)"
  
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
    local artifact_name=$(artifact_name_handling)
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
