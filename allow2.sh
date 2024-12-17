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

    # Extract the PR number and commit SHA from the response
    PR_NUMBER=$(echo "$PR_RESPONSE" | grep -o '"number": [0-9]*' | cut -d ':' -f 2 | tr -d '[:space:]')
    COMMIT_SHA=$(echo "$PR_RESPONSE" | grep -o '"head": {[^}]*"sha": "[^"]*' | cut -d '"' -f 6)

    if [ -z "$PR_NUMBER" ] || [ -z "$COMMIT_SHA" ]; then
        echo "Failed to create PR or retrieve commit SHA."
        exit 1
    fi

    echo "Pull request created successfully. PR Number: $PR_NUMBER"
    echo "Commit SHA for PR #$PR_NUMBER: $COMMIT_SHA"
}

# Step 2: Get the check runs associated with the PR's commit
get_check_runs() {
    if [ -z "$COMMIT_SHA" ]; then
        echo "No commit SHA found. Unable to fetch check runs."
        exit 1
    fi

    echo "Fetching check runs for PR #$PR_NUMBER using commit SHA $COMMIT_SHA..."

    # Fetch check runs for the commit (associated with the PR)
    CHECK_RUNS=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "$API_URL/repos/$GITHUB_OWNER/$GITHUB_REPO/commits/$COMMIT_SHA/check-runs")

    # Check if the response contains check runs
    if echo "$CHECK_RUNS" | grep -q '"check_name"'; then
        echo "List of job names and statuses associated with PR #$PR_NUMBER:"
        
        # Extract and list job names, statuses, and conclusions
        echo "$CHECK_RUNS" | grep -o '"check_name": "[^"]*' | cut -d '"' -f 4 | while read check_name; do
            # Extract the status for each check (queued, in_progress, completed)
            status=$(echo "$CHECK_RUNS" | grep -o "\"check_name\": \"$check_name\".*\"status\": \"[^\"]*" | cut -d '"' -f 8)
            conclusion=$(echo "$CHECK_RUNS" | grep -o "\"check_name\": \"$check_name\".*\"conclusion\": \"[^\"]*" | cut -d '"' -f 8)
            echo "Job Name: $check_name, Status: $status, Conclusion: $conclusion"
        done
    else
        echo "No check runs found for this PR."
    fi
}

# Main Execution
create_pr
get_check_runs
