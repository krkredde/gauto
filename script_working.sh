#!/bin/bash

# Configuration variables
GITHUB_TOKEN="XX"    # Replace with your GitHub Personal Access Token
REPO_OWNER="krkredde"               # Replace with the GitHub repository owner
REPO_NAME="gauto"                   # Replace with the GitHub repository name
BRANCH_NAME="QA_AUTO"            # Replace with your feature branch
BASE_BRANCH="main"                  # The base branch to merge into (usually 'main')
PR_TITLE="Automated PR to main"     # The title of the PR
PR_BODY="This PR is automatically created and merged from the auto_merge branch."
API_URL="https://api.github.com"
HEADERS="Authorization: token $GITHUB_TOKEN"

# Function to create Pull Request using GitHub REST API
create_pr() {
  echo "Creating PR from '$BRANCH_NAME' to '$BASE_BRANCH'..."

  # Create a new pull request
  pr_response=$(curl -s -X POST "$API_URL/repos/$REPO_OWNER/$REPO_NAME/pulls" \
    -H "$HEADERS" \
    -d @- <<EOF
{
  "title": "$PR_TITLE",
  "body": "$PR_BODY",
  "head": "$BRANCH_NAME",
  "base": "$BASE_BRANCH"
}
EOF
  )

  # Extract PR URL, ID, and number
  PR_URL=$(echo "$pr_response" | grep -o '"html_url":\s*"[^"]*' | sed 's/"html_url": "//')
  PR_ID=$(echo "$pr_response" | grep -o '"id":\s*[0-9]*' | sed 's/"id": //')
  PR_NUMBER=$(echo "$pr_response" | grep -o '"number":\s*[0-9]*' | sed 's/"number": //')

  if [ -z "$PR_URL" ] || [ -z "$PR_ID" ]; then
    echo "Error: Failed to create Pull Request."
    echo "Response from GitHub API: $pr_response"
    exit 1
  fi

  echo "Pull Request created: $PR_URL"
}

# Function to check the status of CI checks using check-runs API
check_ci_status() {
  echo "Checking CI status for PR #$PR_NUMBER..."

  # Get the latest commit SHA from the PR
  commit_sha=$(curl -s "$API_URL/repos/$REPO_OWNER/$REPO_NAME/pulls/$PR_NUMBER/commits" \
    -H "$HEADERS" | grep -o '"sha":\s*"[^"]*' | sed 's/"sha": "//' | head -n 1)

  if [ -z "$commit_sha" ]; then
    echo "Error: Unable to fetch commit SHA for PR #$PR_NUMBER."
    exit 1
  fi

  # Poll the check runs status every 30 seconds until all checks are completed and passed
  while true; do
    # Get check runs status for the commit
    check_runs_response=$(curl -s "$API_URL/repos/$REPO_OWNER/$REPO_NAME/commits/$commit_sha/check-runs" -H "$HEADERS")

    # Extract the statuses of all checks
    check_statuses=$(echo "$check_runs_response" | grep -o '"status":\s*"[^"]*' | sed 's/"status": "//')
    check_conclusions=$(echo "$check_runs_response" | grep -o '"conclusion":\s*"[^"]*' | sed 's/"conclusion": "//')

    # Check if any checks are in progress or queued
    in_progress=$(echo "$check_statuses" | grep -c "in_progress")
    queued=$(echo "$check_statuses" | grep -c "queued")

    # Check if there are any failed checks or checks without conclusions
    failed=$(echo "$check_conclusions" | grep -c "failure")
    neutral=$(echo "$check_conclusions" | grep -c "neutral")
    no_conclusion=$(echo "$check_conclusions" | grep -c "^$")

    # If there are still checks in progress or queued, continue waiting
    if [ "$in_progress" -gt 0 ] || [ "$queued" -gt 0 ]; then
      echo "Checks are still in progress or queued. Waiting..."
    # If there are failed or neutral checks, continue waiting
    elif [ "$failed" -gt 0 ] || [ "$neutral" -gt 0 ] || [ "$no_conclusion" -gt 0 ]; then
      echo "Some checks failed or are neutral. Waiting for the checks to pass..."
    else
      echo "All checks have passed."
      break
    fi

    # Wait for 30 seconds before polling again
    sleep 30
  done
}

# Function to merge the Pull Request once all checks pass
merge_pr() {
  echo "Merging PR #$PR_NUMBER..."

  # Merge the pull request
  merge_response=$(curl -s -X PUT "$API_URL/repos/$REPO_OWNER/$REPO_NAME/pulls/$PR_NUMBER/merge" \
    -H "$HEADERS" \
    -d @- <<EOF
{
  "commit_title": "Merging PR #$PR_NUMBER",
  "merge_method": "merge"
}
EOF
  )

  # Check if the merge was successful
  merge_state=$(echo "$merge_response" | grep -o '"state":\s*"[^"]*' | sed 's/"state": "//')

  if [ "$merge_state" == "merged" ]; then
    echo "PR #$PR_NUMBER successfully merged into $BASE_BRANCH."
  else
    echo "Error: PR merge failed."
    echo "Response from GitHub API: $merge_response"
    exit 1
  fi
}

# Step 1: Create the Pull Request
create_pr

# Step 2: Monitor the CI checks until they pass
check_ci_status

# Step 3: Merge the Pull Request once all checks pass
merge_pr