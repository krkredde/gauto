#!/bin/bash

# Replace these variables with your own values
GITHUB_USER="krkredde"
GITHUB_REPO="gauto"
GITHUB_TOKEN="xxxx"
BASE_BRANCH="main"  # The branch from which the PR will be created
HEAD_BRANCH="auto_merge"  # The branch with the changes
PR_TITLE="Automated PR Creation"
PR_BODY="This is an automated pull request created by a script."
GITHUB_API="https://api.github.com"

# Global variable to hold the check suite ID
check_suite_id=""

# Function to create a pull request
create_pr() {
  echo "Creating a pull request from $HEAD_BRANCH to $BASE_BRANCH..."

  response=$(curl -s -X POST \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    -d "{
          \"title\": \"$PR_TITLE\",
          \"body\": \"$PR_BODY\",
          \"head\": \"$HEAD_BRANCH\",
          \"base\": \"$BASE_BRANCH\"
        }" \
    "$GITHUB_API/repos/$GITHUB_USER/$GITHUB_REPO/pulls")

  pr_url=$(echo "$response" | grep -o '"url": "[^"]*' | cut -d '"' -f 4)
  pr_number=$(echo "$response" | grep -o '"number": [0-9]*' | cut -d ':' -f 2 | tr -d '[:space:]')

  if [[ -z "$pr_url" || -z "$pr_number" ]]; then
    echo "Error creating pull request. Response: $response"
    exit 1
  fi

  echo "Pull request created successfully! PR URL: $pr_url"
  echo "PR Number: $pr_number"
}

# Function to list check runs in a check suite
list_check_runs() {
  # Get the latest commit SHA on the base branch
  echo "Fetching latest commit SHA on the $BASE_BRANCH branch..."

  latest_commit_sha=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "$GITHUB_API/repos/$GITHUB_USER/$GITHUB_REPO/commits/$BASE_BRANCH" | \
    grep -o '"sha": "[^"]*' | head -n 1 | cut -d '"' -f 4)

  if [[ -z "$latest_commit_sha" ]]; then
    echo "Error: Could not retrieve the latest commit SHA."
    exit 1
  fi

  echo "Fetching check suite ID for the latest commit $latest_commit_sha..."

  check_suite_id=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "$GITHUB_API/repos/$GITHUB_USER/$GITHUB_REPO/commits/$latest_commit_sha/check-suites" | \
    grep -o '"id": [0-9]*' | head -n 1 | cut -d ':' -f 2 | tr -d '[:space:]')

  if [[ -z "$check_suite_id" ]]; then
    echo "Error: Could not find check suite ID for commit $latest_commit_sha."
    exit 1
  fi

  # List the check runs in the check suite
  echo "Listing check runs for check suite ID $check_suite_id..."
  curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "$GITHUB_API/repos/$GITHUB_USER/$GITHUB_REPO/check-suites/$check_suite_id/check-runs" | \
    grep -o '"name": "[^"]*' | sed 's/"name": "//g'
}

# Function to display check suite status
display_check_suite_status() {
  if [[ -z "$check_suite_id" ]]; then
    echo "Error: No check suite ID found."
    exit 1
  fi

  echo "Fetching check suite status..."

  check_suite_status=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "$GITHUB_API/repos/$GITHUB_USER/$GITHUB_REPO/check-suites/$check_suite_id" | \
    grep -o '"status": "[^"]*' | cut -d '"' -f 4)

  if [[ -z "$check_suite_status" ]]; then
    echo "Error: Could not retrieve the check suite status."
    exit 1
  fi

  echo "Check suite status: $check_suite_status"
}

# Main execution
create_pr
list_check_runs
display_check_suite_status
