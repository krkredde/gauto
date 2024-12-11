#!/bin/bash

# Configuration variables
GITHUB_TOKEN="YOUR_GITHUB_TOKEN"    # Replace with your GitHub Personal Access Token
REPO_OWNER="krkredde"               # Replace with the GitHub repository owner
REPO_NAME="gauto"                   # Replace with the GitHub repository name
BRANCH_NAME="auto_merge"            # Replace with your feature branch
BASE_BRANCH="main"                  # The base branch to merge into (usually 'main')
PR_TITLE="Automated PR to main"     # The title of the PR
PR_BODY="This PR is automatically created from the auto_merge branch."
API_URL="https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/pulls"

# Function to create Pull Request using GitHub REST API
create_pr() {
  echo "Creating PR from '$BRANCH_NAME' to '$BASE_BRANCH'..."

  pr_response=$(curl -s -X POST -H "Authorization: token $GITHUB_TOKEN" \
    -d '{
      "title": "'"$PR_TITLE"'",
      "head": "'"$BRANCH_NAME"'",
      "base": "'"$BASE_BRANCH"'",
      "body": "'"$PR_BODY"'"
    }' "$API_URL")

  PR_URL=$(echo "$pr_response" | grep -o '"html_url":\s*"[^"]*' | sed 's/"html_url": "//')
  PR_NUMBER=$(echo "$pr_response" | grep -o '"number":\s*[0-9]*' | sed 's/"number": //')

  if [ -z "$PR_URL" ] || [ -z "$PR_NUMBER" ]; then
    echo "Error: Failed to create Pull Request."
    echo "Response from GitHub API: $pr_response"
    exit 1
  fi

  echo "Pull Request created: $PR_URL"
}

# Function to fetch check status for the latest commit of the PR
get_check_status() {
  echo "Fetching check status for PR #$PR_NUMBER..."

  checks_response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "$API_URL/$PR_NUMBER/commits")

  commit_sha=$(echo "$checks_response" | grep -o '"sha":\s*"[^"]*' | sed 's/"sha": "//' | head -n 1)

  checks_url="https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/commits/$commit_sha/status"
  checks_response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" "$checks_url")

  check_statuses=$(echo "$checks_response" | grep -o '"state":\s*"[^"]*' | sed 's/"state": "//')
  check_contexts=$(echo "$checks_response" | grep -o '"context":\s*"[^"]*' | sed 's/"context": "//')

  all_checks_completed=true
  success_count=0
  failure_count=0
  in_progress_count=0

  # Use a regular loop to process the check statuses and contexts
  count=0
  while read -r check_status; do
    check_context=$(echo "$check_contexts" | sed -n "$((count + 1))p")
    echo "Check: $check_context"
    echo "Status: $check_status"

    if [ "$check_status" == "success" ]; then
      success_count=$((success_count + 1))
    elif [ "$check_status" == "failure" ]; then
      failure_count=$((failure_count + 1))
    else
      in_progress_count=$((in_progress_count + 1))
      all_checks_completed=false
    fi
    echo "-----"
    count=$((count + 1))
  done <<< "$check_statuses"

  echo "Summary of Checks:"
  echo "Successful Checks: $success_count"
  echo "Failed Checks: $failure_count"
  echo "In Progress Checks: $in_progress_count"

  return $all_checks_completed
}

# Main execution

# Step 1: Create the Pull Request
create_pr

# Step 2: Monitor the CI checks until they are completed
while true; do
  if get_check_status; then
    break
  fi

  # Wait for checks to complete (poll every 30 seconds)
  echo "Waiting for all checks to finish..."
  sleep 30
done

echo "All checks are completed. You can now merge the PR."

