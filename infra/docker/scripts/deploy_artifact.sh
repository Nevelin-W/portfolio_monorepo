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
  
  # Create extract directory and verify it exists
  mkdir -p "$extract_dir"
  if [ ! -d "$extract_dir" ]; then
    error "Failed to create extract directory: $extract_dir"
    exit 1
  fi
  
  # Extract artifact - contains build files ready for deployment
  info "Extracting artifact..."
  
  if [ "$VERBOSE" == "true" ]; then
    tar -xzf "$artifact_path" -C "$extract_dir"
  else
    tar -xzf "$artifact_path" -C "$extract_dir" 2>/dev/null
  fi
  
  # Verify extraction worked
  if [ ! "$(ls -A "$extract_dir" 2>/dev/null)" ]; then
    error "Extraction failed or directory is empty: $extract_dir"
    exit 1
  fi
  
  # Check if files are in a subdirectory and move them up if needed
  local content_count=$(find "$extract_dir" -mindepth 1 -maxdepth 1 | wc -l)
  if [ "$content_count" -eq 1 ]; then
    local single_item=$(find "$extract_dir" -mindepth 1 -maxdepth 1)
    if [ -d "$single_item" ]; then
      # If there's only one directory, move its contents up
      info "Moving contents from subdirectory to root level"
      local temp_dir="/tmp/artifact_temp"
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
  echo "$extract_dir"
}
