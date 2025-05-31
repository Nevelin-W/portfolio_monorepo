#!/usr/bin/env bash
set -eo pipefail

# Default values
REPO_URL=${REPO_URL"}
REPO_BRANCH=${REPO_BRANCH}
PROJECT_PATH=${PROJECT_PATH:}
BUILD_TYPE=${BUILD_TYPE:}
OUTPUT_DIR=${OUTPUT_DIR:}
REPO_NAME=${REPO_NAME}
VERBOSE=${VERBOSE}

# Artifact configuration
ARTIFACT_BUCKET=${ARTIFACT_BUCKET}  # S3 bucket for storing build artifacts
ARTIFACT_PREFIX=${ARTIFACT_PREFIX:-"artifacts/portfolio"}
VERSION=${VERSION:-$(date +%Y%m%d-%H%M%S)-$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")}

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

# Clone repo
clone_repo() {
  info "Cloning repository: $REPO_URL branch: $REPO_BRANCH"
  local clone_dir="/app/$REPO_NAME"
  [ -d "$clone_dir" ] && rm -rf "$clone_dir"
  git clone --branch "$REPO_BRANCH" --single-branch "$REPO_URL" "$clone_dir"
  success "Repository cloned successfully"
}

# Build project
build_project() {
  local project_dir="/app/$REPO_NAME/$PROJECT_PATH"
  info "Building Flutter project at $project_dir"
  cd "$project_dir"
  
  info "Installing dependencies..."
  if [ "$VERBOSE" == "true" ]; then
    flutter pub get
  else
    flutter pub get > /dev/null 2>&1
  fi
  
  info "Building Flutter $BUILD_TYPE..."
  if [ "$VERBOSE" == "true" ]; then
    flutter build $BUILD_TYPE --release
  else
    flutter build $BUILD_TYPE --release > /dev/null 2>&1
  fi
  success "Flutter build completed successfully"
}

# Create build metadata
create_build_metadata() {
  local build_dir="/app/$REPO_NAME/$PROJECT_PATH/$OUTPUT_DIR"
  local metadata_file="$build_dir/build-metadata.json"
  
  info "Creating build metadata..."
  
  # Get git information
  cd "/app/$REPO_NAME"
  local git_commit=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
  local git_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
  local git_tag=$(git describe --tags --exact-match 2>/dev/null || echo "")
  
  # Create metadata JSON
  cat > "$metadata_file" << EOF
{
  "version": "$VERSION",
  "build_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "git": {
    "commit": "$git_commit",
    "branch": "$git_branch",
    "tag": "$git_tag"
  },
  "build": {
    "type": "$BUILD_TYPE",
    "flutter_version": "$(flutter --version | head -n1 || echo "unknown")"
  },
  "artifact": {
    "name": "portfolio-$VERSION.tar.gz",
    "bucket": "$ARTIFACT_BUCKET",
    "key": "$ARTIFACT_PREFIX/portfolio-$VERSION.tar.gz"
  }
}
EOF
  
  success "Build metadata created at $metadata_file"
}

# Create and upload artifact
create_artifact() {
  local build_dir="/app/$REPO_NAME/$PROJECT_PATH/$OUTPUT_DIR"
  local artifact_name="portfolio-$VERSION.tar.gz"
  local artifact_path="/tmp/$artifact_name"
  
  info "Creating artifact: $artifact_name"
  
  # Create tarball
  cd "$build_dir"
  tar -czf "$artifact_path" .
  
  # Upload to S3 artifact bucket
  if [ -z "$ARTIFACT_BUCKET" ]; then
    error "ARTIFACT_BUCKET environment variable is required for artifact storage"
    exit 1
  fi
  
  info "Uploading artifact to S3: s3://$ARTIFACT_BUCKET/$ARTIFACT_PREFIX/$artifact_name"
  
  if [ "$VERBOSE" == "true" ]; then
    aws s3 cp "$artifact_path" "s3://$ARTIFACT_BUCKET/$ARTIFACT_PREFIX/$artifact_name" \
      --metadata "version=$VERSION,build-date=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  else
    aws s3 cp "$artifact_path" "s3://$ARTIFACT_BUCKET/$ARTIFACT_PREFIX/$artifact_name" \
      --metadata "version=$VERSION,build-date=$(date -u +%Y-%m-%dT%H:%M:%SZ)" > /dev/null 2>&1
  fi
  
  success "Artifact uploaded successfully"
  
  # Output artifact information for GitHub Actions
  echo "ARTIFACT_VERSION=$VERSION" >> $GITHUB_OUTPUT
  echo "ARTIFACT_NAME=$artifact_name" >> $GITHUB_OUTPUT
  echo "ARTIFACT_S3_KEY=$ARTIFACT_PREFIX/$artifact_name" >> $GITHUB_OUTPUT
  
  # Clean up local artifact
  rm -f "$artifact_path"
}

# List recent artifacts
list_artifacts() {
  if [ -z "$ARTIFACT_BUCKET" ]; then
    info "No artifact bucket specified, skipping artifact listing"
    return
  fi
  
  info "Recent artifacts in s3://$ARTIFACT_BUCKET/$ARTIFACT_PREFIX/:"
  aws s3 ls "s3://$ARTIFACT_BUCKET/$ARTIFACT_PREFIX/" --recursive | tail -10 || true
}

# Main
main() {
  info "Starting build process with versioning"
  info "Version: $VERSION"
  
  check_aws_credentials
  clone_repo
  build_project
  create_build_metadata
  create_artifact
  list_artifacts
  
  success "Build and artifact creation completed successfully!"
  info "Artifact version: $VERSION"
}

main "$@"