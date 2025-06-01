#!/usr/bin/env bash
set -eo pipefail

# Default values with proper assignments
REPO_URL=${REPO_URL:-""}
REPO_BRANCH=${REPO_BRANCH:-"main"}
PROJECT_PATH=${PROJECT_PATH:-""}
BUILD_TYPE=${BUILD_TYPE:-"web"}
OUTPUT_DIR=${OUTPUT_DIR:-"build/web"}
REPO_NAME=${REPO_NAME:-""}
VERBOSE=${VERBOSE:-"false"}

# Artifact configuration
ARTIFACT_BUCKET=${ARTIFACT_BUCKET:-""}  # S3 bucket for storing build artifacts
ARTIFACT_PREFIX=${ARTIFACT_PREFIX:-"artifacts/portfolio"}
VERSION=${VERSION:-$(date +%Y%m%d-%H%M%S)-$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")}

# Validate required parameters
if [ -z "$REPO_URL" ] || [ -z "$PROJECT_PATH" ] || [ -z "$REPO_NAME" ]; then
    echo "ERROR: Required environment variables are missing:"
    [ -z "$REPO_URL" ] && echo "  - REPO_URL"
    [ -z "$PROJECT_PATH" ] && echo "  - PROJECT_PATH"
    [ -z "$REPO_NAME" ] && echo "  - REPO_NAME"
    exit 1
fi

# Configure logging
log() {
  local level=$1
  shift
  if [[ $VERBOSE == "true" ]] || [[ $level != "DEBUG" ]]; then
    echo "[$level] $(date '+%Y-%m-%d %H:%M:%S') - $@"
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
  
  # Clean up any existing directory
  if [ -d "$clone_dir" ]; then
    info "Removing existing directory: $clone_dir"
    rm -rf "$clone_dir"
  fi
  
  # Clone repository
  if [ "$VERBOSE" == "true" ]; then
    git clone --branch "$REPO_BRANCH" --single-branch "$REPO_URL" "$clone_dir"
  else
    git clone --branch "$REPO_BRANCH" --single-branch "$REPO_URL" "$clone_dir" > /dev/null 2>&1
  fi
  
  success "Repository cloned successfully to $clone_dir"
}

# Build project
build_project() {
  local project_dir="/app/$REPO_NAME/$PROJECT_PATH"
  info "Building Flutter project at $project_dir"
  
  # Verify project directory exists
  if [ ! -d "$project_dir" ]; then
    error "Project directory does not exist: $project_dir"
    exit 1
  fi
  
  cd "$project_dir"
  
  # Verify it's a Flutter project
  if [ ! -f "pubspec.yaml" ]; then
    error "Not a Flutter project: pubspec.yaml not found in $project_dir"
    exit 1
  fi
  
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
  
  # Verify build output exists
  if [ ! -d "$OUTPUT_DIR" ]; then
    error "Build output directory does not exist: $OUTPUT_DIR"
    exit 1
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
  local flutter_version=$(flutter --version | head -n1 2>/dev/null || echo "unknown")
  
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
    "flutter_version": "$flutter_version"
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
  
  # Verify build directory exists and has content
  if [ ! -d "$build_dir" ] || [ -z "$(ls -A "$build_dir")" ]; then
    error "Build directory is empty or does not exist: $build_dir"
    exit 1
  fi
  
  # Create tarball
  cd "$build_dir"
  tar -czf "$artifact_path" .
  
  # Verify artifact was created
  if [ ! -f "$artifact_path" ]; then
    error "Failed to create artifact: $artifact_path"
    exit 1
  fi
  
  local artifact_size=$(du -h "$artifact_path" | cut -f1)
  info "Artifact created successfully (size: $artifact_size)"
  
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
  if [ -n "$GITHUB_OUTPUT" ]; then
    echo "ARTIFACT_VERSION=$VERSION" >> $GITHUB_OUTPUT
    echo "ARTIFACT_NAME=$artifact_name" >> $GITHUB_OUTPUT
    echo "ARTIFACT_S3_KEY=$ARTIFACT_PREFIX/$artifact_name" >> $GITHUB_OUTPUT
  fi
  
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
  if aws s3 ls "s3://$ARTIFACT_BUCKET/$ARTIFACT_PREFIX/" --recursive > /dev/null 2>&1; then
    aws s3 ls "s3://$ARTIFACT_BUCKET/$ARTIFACT_PREFIX/" --recursive | tail -10
  else
    info "No artifacts found or unable to list artifacts"
  fi
}

# Main
main() {
  info "Starting build process with versioning"
  info "Configuration:"
  info "  Repository: $REPO_URL"
  info "  Branch: $REPO_BRANCH"
  info "  Project Path: $PROJECT_PATH"
  info "  Build Type: $BUILD_TYPE"
  info "  Version: $VERSION"
  info "  Verbose: $VERBOSE"
  
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
