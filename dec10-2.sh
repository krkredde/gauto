#!/bin/bash

# Configuration variables
GITHUB_TOKEN="YOUR_GITHUB_TOKEN"    # Replace with your GitHub Personal Access Token
REPO_OWNER="krkredde"               # Replace with the GitHub repository owner
REPO_NAME="gauto"                   # Replace with the GitHub repository name
BRANCH_NAME="auto_merge"            # Replace with your feature branch
BASE_BRANCH="main"                  # The base branch to merge into (usually 'main')
PR_TITLE="Automated PR to main"     # The title of the PR
PR_BODY="This PR is automatically created and merged from the auto_merge branch."
API_URL="https://api.github.com"
HEADERS="Authorization: token $GITHUB_TOKEN"
ALLOW_AUTO_MERGE=true              # Set to true to auto-merge when checks pass, false to disable

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
  
  # Extract PR URL and number
  PR_URL=$(echo "$pr_response" | grep -o '"html_url":\s*"[^"]*' | sed 's/"html_url": "//')
  PR_NUMBER=$(echo "$pr_response" | grep -o '"number":\s*[0-9]*' | sed 's/"number": //')

  if [ -z "$PR_URL" ] || [ -z "$PR_NUMBER" ]; then
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

  # Poll the check runs status every 30 seconds until all checks are completed
  while true; do
    # Get check runs status for the commit
    check_runs_response=$(curl -s "$API_URL/repos/$REPO_OWNER/$REPO_NAME/commits/$commit_sha/check-runs" -H "$HEADERS")
    
    # Extract the statuses, conclusions, and names of all checks
    check_statuses=$(echo "$check_runs_response" | grep -o '"status":\s*"[^"]*' | sed 's/"status": "//')
    check_conclusions=$(echo "$check_runs_response" | grep -o '"conclusion":\s*"[^"]*' | sed 's/"conclusion": "//')
    check_names=$(echo "$check_runs_response" | grep -o '"name":\s*"[^"]*' | sed 's/"name": "//')

    # Initialize counters
    successful_count=0
    failing_count=0
    in_progress_count=0
    queued_count=0

    # Loop through each check run and classify them by conclusion
    count=0
    total_checks=0
    for check in $check_names; do
      status=$(echo "$check_statuses" | sed -n "${count}p")
      conclusion=$(echo "$check_conclusions" | sed -n "${count}p")
      check_name=$(echo "$check" | sed -n "${count}p")

      # Display check status
      echo "Check: $check_name"
      echo "Status: $status"
      if [ "$status" == "completed" ]; then
        echo "Conclusion: $conclusion"
      fi
      echo "-----"

      # Classify checks based on their status and conclusion
      if [ "$status" == "in_progress" ]; then
        in_progress_count=$((in_progress_count + 1))
      elif [ "$status" == "queued" ]; then
        queued_count=$((queued_count + 1))
      elif [ "$conclusion" == "success" ]; then
        successful_count=$((successful_count + 1))
      elif [ "$conclusion" == "failure" ] || [ "$conclusion" == "neutral" ]; then
        failing_count=$((failing_count + 1))
      fi

      total_checks=$((total_checks + 1))
      count=$((count + 1))
    done

    # Print summary of check statuses
    echo "Summary of Checks:"
    echo "Total Checks: $total_checks"
    echo "Successful Checks: $successful_count"
    echo "Failing Checks: $failing_count"
    echo "In Progress Checks: $in_progress_count"
    echo "Queued Checks: $queued_count"

    # If there are any checks in progress or queued, wait
    if [ $in_progress_count -gt 0 ] || [ $queued_count -gt 0 ]; then
      echo "Checks are still in progress or queued. Waiting..."
    # If all checks are completed and all are successful, merge the PR
    elif [ $successful_count -eq $total_checks ]; then
      echo "All checks have passed."
      # Check if we should auto-merge
      if [ "$ALLOW_AUTO_MERGE" == true ]; then
        echo "Merging the PR automatically..."
        merge_pr
      else
        echo "Auto-merge is disabled. PR will not be merged."
      fi
      break
    else
      echo "Not all checks have passed. Waiting for all checks to pass..."
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

