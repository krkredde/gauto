#!/bin/bash

# Configuration
GITHUB_TOKEN="your_github_token"
GITHUB_OWNER="krkredde"
GITHUB_REPO="gauto"
SOURCE_BRANCH="main"
TARGET_BRANCH="auto_merge"  # Target branch to merge into
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

    # Extract the PR number from the response
    PR_NUMBER=$(echo "$PR_RESPONSE" | grep -o '"number": [0-9]*' | cut -d ':' -f 2 | tr -d '[:space:]')
    echo "Pull request created successfully. PR Number: $PR_NUMBER"
}

# Step 2: Get the latest commit SHA for the PR (from the `SOURCE_BRANCH`)
get_commit_sha() {
    echo "Fetching the latest commit SHA for PR #$PR_NUMBER..."

    # Get the commit SHA for the PR's source branch
    COMMIT_SHA=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "$API_URL/repos/$GITHUB_OWNER/$GITHUB_REPO/pulls/$PR_NUMBER" | \
        grep -o '"sha": "[^"]*' | cut -d '"' -f 4)

    if [ -z "$COMMIT_SHA" ]; then
        echo "Unable to retrieve commit SHA for PR #$PR_NUMBER."
        exit 1
    fi

    echo "Commit SHA for PR #$PR_NUMBER: $COMMIT_SHA"
}

# Step 3: List all check names for the PR using commit SHA
get_check_names() {
    if [ -z "$COMMIT_SHA" ]; then
        echo "No commit SHA found. Unable to fetch check runs."
        exit 1
    fi

    echo "Fetching check names for PR #$PR_NUMBER using commit SHA $COMMIT_SHA..."
    
    # Fetch check runs for the commit (associated with the PR)
    CHECK_RUNS=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "$API_URL/repos/$GITHUB_OWNER/$GITHUB_REPO/commits/$COMMIT_SHA/check-runs")

    # Debug: print the full response to see what is being returned
    echo "Full API Response for check runs:"
    echo "$CHECK_RUNS"

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
get_commit_sha
get_check_names
