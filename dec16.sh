#!/bin/bash

# Configuration variables
GITHUB_TOKEN="your_github_token"
GITHUB_USER="krkredde"
GITHUB_REPO="gauto"
BRANCH_NAME="auto_merge"  # The branch to be merged into the base branch
BASE_BRANCH="main"                # The base branch (typically main or master)
PR_TITLE="Automated Pull Request"
PR_BODY="This PR was created automatically using a script."
API_URL="https://api.github.com"

# Function to create the pull request
create_pr() {
  echo "Creating pull request from $BRANCH_NAME to $BASE_BRANCH..."

  response=$(curl -s -X POST -H "Authorization: token $GITHUB_TOKEN" \
    -d @- "$API_URL/repos/$GITHUB_USER/$GITHUB_REPO/pulls" <<EOF
{
  "title": "$PR_TITLE",
  "body": "$PR_BODY",
  "head": "$BRANCH_NAME",
  "base": "$BASE_BRANCH"
}
EOF
  )

  # Extract the PR number from the response
  pr_number=$(echo "$response" | grep -o '"number": [0-9]*' | awk '{print $2}')

  if [ -z "$pr_number" ]; then
    echo "Error: Failed to create PR."
    exit 1
  fi

  echo "Created PR #$pr_number"
}

# Function to monitor the status of PR checks
monitor_checks() {
  echo "Monitoring checks for PR #$pr_number..."

  while true; do
    # Fetch the status of the checks for the PR
    check_runs=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
      "$API_URL/repos/$GITHUB_USER/$GITHUB_REPO/pulls/$pr_number/checks")

    # Check if there are no check runs (meaning the checks are not yet reported)
    if echo "$check_runs" | grep -q '"check_runs": \[]'; then
      echo "No checks found for PR #$pr_number. Retrying..."
      sleep 10
      continue
    fi

    # Extract the status and conclusion of each check run
    check_statuses=$(echo "$check_runs" | grep -o '"name": "[^"]*", "status": "[^"]*", "conclusion": "[^"]*"' | sed 's/"name": "//g' | sed 's/", "status": "//g' | sed 's/", "conclusion": "//g' | sed 's/"$//g')

    echo "Check statuses for PR #$pr_number:"
    echo "$check_statuses"

    # Check if all checks are completed (status == 'completed' and conclusion is either 'success' or 'failure')
    all_checks_completed=$(echo "$check_statuses" | grep -E 'completed' | grep -E 'success|failure' | wc -l)

    # If all checks have completed (either success or failure), break out of the loop
    if [ "$all_checks_completed" -gt 0 ]; then
      echo "All checks are completed (success or failure)."
      break
    else
      echo "Checks are still in progress..."
      sleep 10
    fi
  done
}

# Main script logic
create_pr
monitor_checks
echo "All checks are completed for PR #$pr_number."
