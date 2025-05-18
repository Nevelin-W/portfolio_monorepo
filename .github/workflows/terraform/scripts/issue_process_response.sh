#!/bin/bash
# Input variables
GITHUB_TOKEN="$1"
ISSUE_NUMBER="$2"
ENVIRONMENT="$3"
GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-Nevelin-W/portfolio_monorepo}"  # Default or from environment

echo "ISSUE_NUMBER=$ISSUE_NUMBER" >> $GITHUB_OUTPUT

# Validate input variables
if [[ -z "$GITHUB_TOKEN" || -z "$ISSUE_NUMBER" ]]; then
  echo "ERROR: Missing required arguments. Usage: $0 <GITHUB_TOKEN> <ISSUE_NUMBER> <ENVIRONMENT>"
  exit 1
fi

echo "Waiting for approval on issue #$ISSUE_NUMBER in repository $GITHUB_REPOSITORY"

for i in {1..20}; do
  echo "Attempt $i: Checking for approval comments..."
  
  API_RESPONSE=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/$GITHUB_REPOSITORY/issues/$ISSUE_NUMBER/comments")
    
  # Debug info without exposing sensitive data
  RESPONSE_STATUS=$(echo "$API_RESPONSE" | jq -r '.message // "Success"')
  echo "DEBUG: API Response status: $RESPONSE_STATUS"
  
  if echo "$API_RESPONSE" | grep -q '"message": "Not Found"'; then
    echo "ERROR: Issue #$ISSUE_NUMBER not found in repository $GITHUB_REPOSITORY. Exiting."
    exit 1
  fi
  
  COMMENTS=$(echo "$API_RESPONSE" | jq -r '.[].body // ""')
  
  if echo "$COMMENTS" | grep -qi "approve-apply"; then
    echo "✅ Approval found! Proceeding with apply."
    echo "ACTION=apply" >> $GITHUB_OUTPUT
    break
  elif echo "$COMMENTS" | grep -qi "cancel"; then
    echo "❌ Cancellation requested. Aborting workflow."
    echo "ACTION=cancel" >> $GITHUB_OUTPUT
    break
  fi
  
  # Check if we've reached the maximum number of attempts
  if [ $i -eq 20 ]; then
    echo "❌ No approval received after maximum number of attempts. Aborting workflow."
    echo "ACTION=timeout" >> $GITHUB_OUTPUT
    exit 0
  fi
  
  echo "No approval yet. Checking again in 30 seconds..."
  sleep 30
done

# Close the issue with a comment indicating the action taken
ACTION=$(grep "ACTION=" $GITHUB_OUTPUT | cut -d= -f2)
COMMENT_TEXT=""

if [ "$ACTION" == "apply" ]; then
  COMMENT_TEXT="✅ Approval received. Proceeding with Terraform apply for $ENVIRONMENT environment."
elif [ "$ACTION" == "cancel" ]; then
  COMMENT_TEXT="❌ Cancellation requested. Workflow aborted."
else
  COMMENT_TEXT="⏱️ Timeout reached. No action taken within the waiting period."
fi

# Post closing comment
curl -s -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  -d "{\"body\":\"$COMMENT_TEXT\"}" \
  "https://api.github.com/repos/$GITHUB_REPOSITORY/issues/$ISSUE_NUMBER/comments"

# Close the issue
curl -s -X PATCH \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  -d '{"state":"closed"}' \
  "https://api.github.com/repos/$GITHUB_REPOSITORY/issues/$ISSUE_NUMBER"

echo "Issue #$ISSUE_NUMBER closed with final status: $ACTION"
