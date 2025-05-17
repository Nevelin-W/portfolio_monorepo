#!/bin/bash

# Ensure required arguments are provided
if [ $# -lt 4 ]; then
  echo "Usage: $0 <GITHUB_TOKEN> <ISSUE_NUMBER> <ACTION_TAKEN> <GITHUB_REPOSITORY> <COMMENT>"
  exit 1
fi

GITHUB_TOKEN=$1
ISSUE_NUMBER=$2
ACTION_TAKEN=$3
GITHUB_REPOSITORY=$4
COMMENT=$5

# Make a request to add a comment to the issue
curl -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  -d "{\"body\": \"$COMMENT\"}" \
  "https://api.github.com/repos/$GITHUB_REPOSITORY/issues/$ISSUE_NUMBER/comments"
