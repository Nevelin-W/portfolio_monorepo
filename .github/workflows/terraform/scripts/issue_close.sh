#!/bin/bash

# Ensure required arguments are provided
if [ $# -lt 3 ]; then
  echo "Usage: $0 <GITHUB_TOKEN> <ISSUE_NUMBER> <GITHUB_REPOSITORY>"
  exit 1
fi

GITHUB_TOKEN=$1
ISSUE_NUMBER=$2
GITHUB_REPOSITORY=$3

# Make a request to close the issue
curl -X PATCH \
  -H "Authorization: token $GITHUB_TOKEN" \
  -d '{"state": "closed"}' \
  "https://api.github.com/repos/$GITHUB_REPOSITORY/issues/$ISSUE_NUMBER"
