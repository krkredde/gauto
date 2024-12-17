#!/bin/bash

# Configuration
GITHUB_TOKEN="your_github_token"
GITHUB_OWNER="krkredde"
GITHUB_REPO="gauto"
SOURCE_BRANCH="auto_merge"
TARGET_BRANCH="main"  # Target branch to merge into
PR_TITLE="Automated PR"
PR_BODY="This is an automated PR created using a shell script."
API_URL="https://api.github.com"

# Step 1: Create a Pull Request
create_pr() {
    echo "Creating PR from $SOURCE_BRANCH to $TARGET_BRANCH..."
    
    PR_RESPONSE=$(curl -s -X POST "$API_URL/repos/$GITHUB_OWNER/$GITHUB_REPO/pulls" \
        -H "Authorization: token $GITHUB_TOKEN" \
        -d @- <<EOF
{
  "title": "$PR_TITLE",
  "body": "$PR_BODY",
  "head": "$SOURCE_BRANCH",
  "base": "$TARGET_BRANCH"
}
EOF
    )

    # Extract the PR number and SHA from the response
    PR_NUMBER=$(echo "$PR_RESPONSE" | grep -o '"number": [0-9]*' | cut -d ':' -f 2 | tr -d '[:space:]')
    PR_SHA=$(echo "$PR_RESPONSE" | grep -o '"sha": "[^"]*' | cut -d '"' -f 4)
    echo "Pull request created successfully. PR Number: $PR_NUMBER"
    echo "Commit SHA for PR: $PR_SHA"
}

# Step 2: List all check names for the PR
get_check_names() {
    if [ -z "$PR_SHA" ]; then
        echo "No commit SHA found. Unable to fetch check runs."
        exit 1
    fi

    echo "Fetching check names for PR #$PR_NUMBER using commit SHA $PR_SHA..."
    
    # Fetch check runs for the commit (associated with the PR)
    CHECK_RUNS=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "$API_URL/repos/$GITHUB_OWNER/$GITHUB_REPO/commits/$PR_SHA/check-runs")
    
    # Check if there are any check runs
    if echo "$CHECK_RUNS" | grep -q '"check_name"'; then
        echo "List of check names associated with PR #$PR_NUMBER:"
        # Extract and list all check names
        echo "$CHECK_RUNS" | grep -o '"check_name": "[^"]*' | cut -d '"' -f 4
    else
        echo "No check runs found for this PR."
    fi
}

# Main Execution
create_pr
get_check_names

