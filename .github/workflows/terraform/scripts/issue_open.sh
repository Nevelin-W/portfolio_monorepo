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

# Extract Terraform plan output
PLAN_OUTPUT=$(terraform show -no-color "$TERRAFORM_PLAN_FILE")

# Check if there are no changes
if echo "$PLAN_OUTPUT" | grep -q "No changes"; then
  PLAN_SUMMARY="No changes. No objects need to be created, updated, or destroyed."
else
  PLAN_SUMMARY=$(echo "$PLAN_OUTPUT" | grep -E "^Plan:|will be created|will be destroyed|will be updated|must be replaced" | head -10)
fi

# Build issue body
BODY_TEXT=$(cat <<EOF
Please approve or cancel the deployment. Reply with approve-apply or cancel.

## Resources Summary
\`\`\`
${PLAN_SUMMARY}
\`\`\`

**Review the Full Terraform Plan:**
[View Terraform Plan Output](${WORKFLOW_RUN_URL})

The plan artifact is available in the workflow artifacts section.
EOF
)

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
