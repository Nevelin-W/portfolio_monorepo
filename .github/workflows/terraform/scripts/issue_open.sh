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
TERRAFORM_PLAN_FILE="$7"

# Validate input arguments
if [ -z "$GITHUB_TOKEN" ] || [ -z "$GITHUB_SERVER_URL" ] || [ -z "$GITHUB_REPOSITORY" ] || [ -z "$GITHUB_RUN_ID" ]; then
  echo "ERROR: Missing required input parameters"
  exit 1
fi

# Create a link to the workflow run
WORKFLOW_RUN_URL="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"

# For Terraform Cloud plans, we cannot use terraform show directly
# Instead, extract the run_id and create a link to the Terraform Cloud UI
if grep -q "remote_plan_format" "$TERRAFORM_PLAN_FILE" 2>/dev/null; then
  echo "Detected Terraform Cloud plan format"
  
  # Extract the run_id from the file if possible
  TF_CLOUD_RUN_ID=$(grep -o '"run_id":"[^"]*"' "$TERRAFORM_PLAN_FILE" 2>/dev/null | cut -d'"' -f4)
  TF_CLOUD_HOSTNAME=$(grep -o '"hostname":"[^"]*"' "$TERRAFORM_PLAN_FILE" 2>/dev/null | cut -d'"' -f4)
  
  if [ -n "$TF_CLOUD_RUN_ID" ] && [ -n "$TF_CLOUD_HOSTNAME" ]; then
    # Check if we have a proper URL in the log file
    PLAN_URL=$(grep -o "https://.*$TF_CLOUD_RUN_ID" "$GITHUB_WORKSPACE/terraform-plan-output.log" 2>/dev/null || echo "")
    
    if [ -z "$PLAN_URL" ]; then
      # If we don't have the URL from logs, construct a generic one
      PLAN_URL="https://$TF_CLOUD_HOSTNAME/app/-/runs/$TF_CLOUD_RUN_ID"
    fi
    
    PLAN_SUMMARY="This plan was created in Terraform Cloud. Please review the plan in the Terraform Cloud UI."
  else
    PLAN_SUMMARY="Unable to extract Terraform Cloud run information. Please review the plan in the workflow artifacts."
  fi
else
  # For local plans, use terraform show
  echo "Using terraform show for local plan format"
  PLAN_OUTPUT=$(terraform show -no-color "$TERRAFORM_PLAN_FILE" 2>/dev/null || echo "Error reading plan file")
  
  # Check if there are no changes
  if echo "$PLAN_OUTPUT" | grep -q "No changes"; then
    PLAN_SUMMARY="No changes. No objects need to be created, updated, or destroyed."
  else
    PLAN_SUMMARY=$(echo "$PLAN_OUTPUT" | grep -E "^Plan:|will be created|will be destroyed|will be updated|must be replaced" | head -10)
  fi
fi

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
[View in Terraform Cloud](${PLAN_URL})
"
fi

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
  exit 1
fi

# Store ISSUE_NUMBER as output
echo "ISSUE_NUMBER=$ISSUE_NUMBER" >> "$GITHUB_OUTPUT"
echo "Created issue #$ISSUE_NUMBER"
