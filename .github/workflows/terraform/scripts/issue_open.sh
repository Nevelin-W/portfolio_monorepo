#!/bin/bash
# Exit immediately if a command fails
set -e

# Read input arguments
GITHUB_TOKEN="$1"
GITHUB_SERVER_URL="$2"
GITHUB_REPOSITORY="$3"
GITHUB_RUN_ID="$4"
ASSIGNEE="$5"
ISSUE_TITLE="$6"
TERRAFORM_WORKING_DIR="$7"

# Validate input arguments
if [ -z "$GITHUB_TOKEN" ] || [ -z "$GITHUB_SERVER_URL" ] || [ -z "$GITHUB_REPOSITORY" ] || [ -z "$GITHUB_RUN_ID" ]; then
  echo "ERROR: Missing required input parameters"
  exit 1
fi

# Create a link to the workflow run
WORKFLOW_RUN_URL="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"

# Define file paths
PLAN_FILE="${TERRAFORM_WORKING_DIR}/tfout"
LOG_FILE="${GITHUB_WORKSPACE}/terraform-plan-output.log"

echo "Looking for plan file at: $PLAN_FILE"
echo "Looking for log file at: $LOG_FILE"

# Initialize variables
PLAN_SUMMARY=""
PLAN_URL=""

# Check if log file exists and extract Terraform Cloud URL
if [ -f "$LOG_FILE" ]; then
  echo "Log file found, checking for Terraform Cloud URL..."
  
  # Look for Terraform Cloud plan URL in the log file
  PLAN_URL=$(grep -oE "https://app\.terraform\.io/app/[^/]+/[^/]+/runs/[^[:space:]]+" "$LOG_FILE" 2>/dev/null | head -1 || echo "")
  
  if [ -n "$PLAN_URL" ]; then
    echo "Found Terraform Cloud URL: $PLAN_URL"
    PLAN_SUMMARY="This plan was created in Terraform Cloud. Please review the plan in the Terraform Cloud UI."
  else
    echo "No Terraform Cloud URL found in log file"
    # Try to extract plan summary from log file
    if grep -q "No changes" "$LOG_FILE"; then
      PLAN_SUMMARY="No changes. No objects need to be created, updated, or destroyed."
    else
      PLAN_SUMMARY=$(grep -E "^Plan:|will be created|will be destroyed|will be updated|must be replaced" "$LOG_FILE" | head -10 || echo "Plan details available in workflow artifacts.")
    fi
  fi
else
  echo "Log file not found at $LOG_FILE"
  PLAN_SUMMARY="Plan details available in workflow artifacts."
fi

# If we still don't have a summary and the plan file exists, try to read it
if [ -z "$PLAN_SUMMARY" ] && [ -f "$PLAN_FILE" ]; then
  echo "Attempting to read plan file directly..."
  cd "$TERRAFORM_WORKING_DIR"
  PLAN_OUTPUT=$(terraform show -no-color tfout 2>/dev/null || echo "Error reading plan file")
  
  if echo "$PLAN_OUTPUT" | grep -q "No changes"; then
    PLAN_SUMMARY="No changes. No objects need to be created, updated, or destroyed."
  else
    PLAN_SUMMARY=$(echo "$PLAN_OUTPUT" | grep -E "^Plan:|will be created|will be destroyed|will be updated|must be replaced" | head -10 || echo "Plan details available in workflow artifacts.")
  fi
fi

# Fallback if we still don't have a summary
if [ -z "$PLAN_SUMMARY" ]; then
  PLAN_SUMMARY="Plan details available in workflow artifacts."
fi

echo "Plan summary: $PLAN_SUMMARY"

# Build issue body
BODY_TEXT=$(cat <<EOF
Please approve or cancel the deployment. Reply with approve-apply or cancel.

## Resources Summary

\`\`\`
${PLAN_SUMMARY}
\`\`\`

**Review the Full Terraform Plan:**
[View Workflow Run](${WORKFLOW_RUN_URL})
EOF
)

# Add Terraform Cloud URL if available
if [ -n "$PLAN_URL" ]; then
  BODY_TEXT="${BODY_TEXT}

**Terraform Cloud Plan:**
[View in Terraform Cloud](${PLAN_URL})"
fi

echo "Issue body will be:"
echo "$BODY_TEXT"

# Create JSON payload
JSON_PAYLOAD=$(jq -n \
  --arg title "$ISSUE_TITLE" \
  --arg body "$BODY_TEXT" \
  --arg assignee "$ASSIGNEE" \
  '{title: $title, body: $body, assignees: [$assignee]}')

# Create GitHub issue
RESPONSE=$(curl -s -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  -d "$JSON_PAYLOAD" \
  "https://api.github.com/repos/$GITHUB_REPOSITORY/issues")

echo "Full API Response: $RESPONSE"

# Extract issue number
ISSUE_NUMBER=$(echo "$RESPONSE" | jq -r '.number')

if [[ "$ISSUE_NUMBER" == "null" || -z "$ISSUE_NUMBER" ]]; then
  echo "ERROR: Issue creation failed!"
  echo "Response: $RESPONSE"
  exit 1
fi

# Store ISSUE_NUMBER as output
echo "ISSUE_NUMBER=$ISSUE_NUMBER" >> "$GITHUB_OUTPUT"
echo "Created issue #$ISSUE_NUMBER"