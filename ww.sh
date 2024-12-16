#!/bin/bash

# Variables (Customize these with your repository details)
GITHUB_TOKEN="your_github_token_here"
GITHUB_USER="krkredde"
REPO_NAME="gauto"
BASE_BRANCH="main" # The branch you want to base your PR on
FEATURE_BRANCH="auto_merge" # The branch with the changes
PR_TITLE="Auto-generated PR Title"
PR_BODY="Auto-generated PR body description"

# GitHub API URL
API_URL="https://api.github.com"

# Step 1: Create a Pull Request
create_pr() {
    echo "Creating pull request from branch '$FEATURE_BRANCH' to '$BASE_BRANCH'..."

    # Send the request to GitHub API to create the pull request
    PR_RESPONSE=$(curl -s -X POST \
        -H "Authorization: token $GITHUB_TOKEN" \
        -d @- "$API_URL/repos/$GITHUB_USER/$REPO_NAME/pulls" <<EOF
{
  "title": "$PR_TITLE",
  "body": "$PR_BODY",
  "head": "$FEATURE_BRANCH",
  "base": "$BASE_BRANCH"
}
EOF
    )

    # Parse the PR URL from the response
    PR_URL=$(echo $PR_RESPONSE | jq -r .html_url)
    PR_ID=$(echo $PR_RESPONSE | jq -r .number)

    if [[ "$PR_URL" == "null" ]]; then
        echo "Failed to create PR. Response: $PR_RESPONSE"
        exit 1
    fi

    echo "Pull request created successfully: $PR_URL"
}

# Step 2: Check PR status (whether checks passed or failed)
check_pr_status() {
    echo "Checking status of PR $PR_ID..."

    # Get the status of the PR checks (CI/CD checks)
    CHECKS_RESPONSE=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "$API_URL/repos/$GITHUB_USER/$REPO_NAME/pulls/$PR_ID/checks")

    # Parse check statuses
    STATE=$(echo $CHECKS_RESPONSE | jq -r '.state')

    if [[ "$STATE" == "success" ]]; then
        echo "All checks passed for PR #$PR_ID."
    elif [[ "$STATE" == "failure" ]]; then
        echo "Some checks failed for PR #$PR_ID."
    else
        echo "PR checks are still pending for PR #$PR_ID."
    fi
}

# Step 3: Show PR status
show_pr_status() {
    PR_STATUS_RESPONSE=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "$API_URL/repos/$GITHUB_USER/$REPO_NAME/pulls/$PR_ID")

    PR_STATE=$(echo $PR_STATUS_RESPONSE | jq -r '.state')

    if [[ "$PR_STATE" == "open" ]]; then
        echo "Pull Request #$PR_ID is currently open."
    else
        echo "Pull Request #$PR_ID has been closed/merged."
    fi
}

# Main Execution
create_pr
check_pr_status
show_pr_status
