#!/bin/bash

# Input variables
GITHUB_TOKEN="$1"
ISSUE_NUMBER="$2"

echo "ISSUE_NUMBER=$ISSUE_NUMBER" >> $GITHUB_OUTPUT

# Validate input variables
if [[ -z "$GITHUB_TOKEN" || -z "$ISSUE_NUMBER" ]]; then
  echo "ERROR: Missing required arguments. Usage: $0 <GITHUB_TOKEN> <ISSUE_NUMBER>"
  exit 1
fi

echo "Waiting for approval on issue #$ISSUE_NUMBER"

for i in {1..20}; do
  API_RESPONSE=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/Nevelin-W/wls_provisioning/issues/$ISSUE_NUMBER/comments")

  echo "DEBUG: API Response: $API_RESPONSE"

  if echo "$API_RESPONSE" | grep -q '"message": "Not Found"'; then
    echo "ERROR: Issue #$ISSUE_NUMBER not found. Exiting."
    exit 1
  fi

  COMMENTS=$(echo "$API_RESPONSE" | jq -r '.[].body // ""')

  if echo "$COMMENTS" | grep -q "approve-apply"; then
    echo "ACTION=apply" >> $GITHUB_OUTPUT
    break
  elif echo "$COMMENTS" | grep -q "cancel"; then
    echo "ACTION=cancel" >> $GITHUB_OUTPUT
    break
  fi

  echo "No approval yet. Checking again in 10 seconds..."
  sleep 10
done
