#!/bin/bash

# Replace these variables with your own values
GITHUB_USER="krkredde"
GITHUB_REPO="gauto"
GITHUB_TOKEN="your-personal-access-token"
BASE_BRANCH="main"  # The branch from which the PR will be created
HEAD_BRANCH="auto_merge"  # The branch with the changes
PR_TITLE="Automated PR Creation"
PR_BODY="This is an automated pull request created by a script."
GITHUB_API="https://api.github.com"

# Function to create a pull request
create_pr() {
  echo "Creating a pull request from $HEAD_BRANCH to $BASE_BRANCH..."

  curl -X POST \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    -d "{
          \"title\": \"$PR_TITLE\",
          \"body\": \"$PR_BODY\",
          \"head\": \"$HEAD_BRANCH\",
          \"base\": \"$BASE_BRANCH\"
        }" \
    "$GITHUB_API/repos/$GITHUB_USER/$GITHUB_REPO/pulls"
}

# Function to list check runs in a check suite
list_check_runs() {
  # Get the latest commit SHA on the base branch
  echo "Fetching latest commit SHA on the $BASE_BRANCH branch..."

  latest_commit_sha=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "$GITHUB_API/repos/$GITHUB_USER/$GITHUB_REPO/commits/$BASE_BRANCH" | jq -r '.sha')

  # Get the check suite ID for the latest commit
  echo "Fetching check suite ID for the latest commit $latest_commit_sha..."

  check_suite_id=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "$GITHUB_API/repos/$GITHUB_USER/$GITHUB_REPO/commits/$latest_commit_sha/check-suites" | jq -r '.[0].id')

  # List the check runs in the check suite
  echo "Listing check runs for check suite ID $check_suite_id..."

  curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "$GITHUB_API/repos/$GITHUB_USER/$GITHUB_REPO/check-suites/$check_suite_id/check-runs" | jq '.check_runs[] | {name, status, conclusion}'
}

# Function to display check suite status
display_check_suite_status() {
  # Get the check suite status
  echo "Fetching check suite status..."

  check_suite_status=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "$GITHUB_API/repos/$GITHUB_USER/$GITHUB_REPO/check-suites/$check_suite_id" | jq -r '.status')

  echo "Check suite status: $check_suite_status"
}

# Main execution
create_pr
list_check_runs
display_check_suite_status
