#!/bin/bash

# Configuration - Replace with your actual values
GITHUB_TOKEN="your_personal_access_token"  # GitHub Personal Access Token
REPO_OWNER="krkredde"  # GitHub Repo Owner
REPO_NAME="gauto"      # GitHub Repo Name

# Function to create a pull request
create_pull_request() {
  local title="$1"
  local body="$2"
  local head_branch="$3"
  local base_branch="$4"

  # If repo owner is not the same as the username, prepend repo owner to the head branch
  if [ "$REPO_OWNER" != "your-username" ]; then
    head_branch="${REPO_OWNER}:${head_branch}"
  fi

  response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    -X POST -d "{\"title\":\"$title\", \"body\":\"$body\", \"head\":\"$head_branch\", \"base\":\"$base_branch\"}" \
    "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/pulls")

  pr_number=$(echo "$response" | grep -o '"number": [0-9]*' | awk '{print $2}')
  commit_sha=$(echo "$response" | grep -o '"sha": "[a-f0-9]*"' | head -n 1 | awk -F '": "' '{print $2}' | tr -d '"')

  if [ -z "$pr_number" ]; then
    echo "Error creating PR: $response"
    return 1
  else
    echo "PR Created: https://github.com/$REPO_OWNER/$REPO_NAME/pull/$pr_number"
    echo "Commit SHA: $commit_sha"
    echo "$pr_number $commit_sha"
  fi
}

# Function to get check runs for the commit
get_check_runs_for_commit() {
  local commit_sha="$1"

  response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/commits/$commit_sha/check-runs")

  check_runs=$(echo "$response" | grep -o '"name": "[^"]*"' | awk -F '": "' '{print $2}' | tr -d '"')
  statuses=$(echo "$response" | grep -o '"status": "[^"]*"' | awk -F '": "' '{print $2}' | tr -d '"')
  conclusions=$(echo "$response" | grep -o '"conclusion": "[^"]*"' | awk -F '": "' '{print $2}' | tr -d '"')

  if [ -z "$check_runs" ]; then
    echo "No check runs found for this commit."
    return 1
  fi

  echo -e "\nAll Check Runs for Commit:"
  # Create arrays from the check runs, statuses, and conclusions
  IFS=$'\n' read -r -d '' -a check_run_array <<< "$check_runs"
  IFS=$'\n' read -r -d '' -a status_array <<< "$statuses"
  IFS=$'\n' read -r -d '' -a conclusion_array <<< "$conclusions"

  # Loop through arrays to display check runs
  for i in "${!check_run_array[@]}"; do
    check_name="${check_run_array[$i]}"
    status="${status_array[$i]}"
    conclusion="${conclusion_array[$i]}"
    echo "- $check_name ($status) - Conclusion: $conclusion"
  done

  # Return all check names and conclusions
  echo "$check_runs"
  echo "$conclusions"
}

# Function to merge the pull request
merge_pull_request() {
  local pr_number="$1"

  response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    -X PUT -d '{"commit_title":"Merging PR automatically after successful checks","merge_method":"merge"}' \
    "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/pulls/$pr_number/merge")

  if echo "$response" | grep -q '"merged": true'; then
    echo "PR #$pr_number has been successfully merged!"
  else
    echo "Error merging PR: $response"
  fi
}

# Example usage
# Create PR
echo "Creating PR..."
result=$(create_pull_request "Automated Merge PR" "This is an automated pull request to merge 'auto_merge' into 'main'." "auto_merge" "main")

# Extract PR number and commit SHA from result
pr_number=$(echo "$result" | awk '{print $1}')
commit_sha=$(echo "$result" | awk '{print $2}')

# If PR was created successfully, get check runs
if [ -n "$pr_number" ] && [ -n "$commit_sha" ]; then
  echo "Fetching check runs for commit $commit_sha..."

  # Get check runs for the commit
  check_runs=$(get_check_runs_for_commit "$commit_sha")

  if [ -n "$check_runs" ]; then
    npm_status=$(echo "$check_runs" | grep -A 1 "Run npm on Ubuntu" | tail -n 1)
    build_status=$(echo "$check_runs" | grep -A 1 "build" | tail -n 1)

    echo -e "\nCurrent status of required checks:"
    echo "Run npm on Ubuntu: $npm_status"
    echo "Build: $build_status"

    # Only merge if both checks are successful
    if [ "$npm_status" == "success" ] && [ "$build_status" == "success" ]; then
      merge_pull_request "$pr_number"
    else
      echo "\nRequired checks have not passed. PR will not be merged."
      if [ "$npm_status" != "success" ]; then
        echo " - 'Run npm on Ubuntu' check failed."
      fi
      if [ "$build_status" != "success" ]; then
        echo " - 'build' check failed."
      fi
    fi
  else
    echo "No check runs found. Exiting."
  fi
else
  echo "PR creation failed. Exiting."
fi
