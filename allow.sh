#!/bin/bash

# Configuration
GITHUB_TOKEN="your_github_token"
GITHUB_OWNER="krkredde"
GITHUB_REPO="gauto"
SOURCE_BRANCH="auto_merge"
TARGET_BRANCH="main"
PR_TITLE="Automated PR Title"
PR_BODY="This is an automated PR created by a shell script."
API_URL="https://api.github.com"

# Create the PR
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

    # Extract PR URL
    PR_URL=$(echo "$PR_RESPONSE" | grep -o '"url": "[^"]*' | cut -d '"' -f 4)
    echo "Pull Request created at $PR_URL"
}

# Check the status of PR checks
wait_for_checks() {
    PR_NUMBER=$(echo "$PR_URL" | awk -F'/' '{print $NF}')
    echo "Waiting for checks to pass for PR #$PR_NUMBER..."

    while true; do
        # Fetch PR status
        PR_STATUS=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
            "$API_URL/repos/$GITHUB_OWNER/$GITHUB_REPO/pulls/$PR_NUMBER")

        # Print the full PR status response for debugging
        echo "PR Status Response: $PR_STATUS"

        # Check for the mergeable field
        MERGEABLE=$(echo "$PR_STATUS" | grep -o '"mergeable": [^,]*' | cut -d ':' -f 2 | tr -d '[:space:]')

        # Handle cases where mergeable is missing or null
        if [[ -z "$MERGEABLE" ]]; then
            echo "Mergeable field is missing. This might indicate the PR is still processing or incomplete."
        elif [[ "$MERGEABLE" == "true" ]]; then
            echo "PR #$PR_NUMBER is mergeable!"
            break
        elif [[ "$MERGEABLE" == "false" ]]; then
            echo "PR #$PR_NUMBER is not mergeable due to conflicts or failed checks."
            exit 1
        elif [[ "$MERGEABLE" == "null" ]]; then
            echo "PR #$PR_NUMBER is still being processed or there are unresolved conflicts."
        else
            echo "Unexpected mergeable value: $MERGEABLE"
            exit 1
        fi

        # Check for individual status checks (optional: you can extend this)
        CHECKS=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
            "$API_URL/repos/$GITHUB_OWNER/$GITHUB_REPO/pulls/$PR_NUMBER/checks")

        # Print status checks response
        echo "PR Checks Status: $CHECKS"

        # You can add logic to check specific statuses for your CI checks here

        echo "Waiting 10 seconds before re-checking..."
        sleep 10  # Wait for 10 seconds before checking again
    done
}

# Merge the PR
merge_pr() {
    echo "Merging PR #$PR_NUMBER..."
    MERGE_RESPONSE=$(curl -s -X PUT "$API_URL/repos/$GITHUB_OWNER/$GITHUB_REPO/pulls/$PR_NUMBER/merge" \
        -H "Authorization: token $GITHUB_TOKEN" \
        -d '{"merge_method": "merge"}')

    MERGE_STATUS=$(echo "$MERGE_RESPONSE" | grep -o '"merged": [^,]*' | cut -d ':' -f 2 | tr -d '[:space:]')
    
    if [[ "$MERGE_STATUS" == "true" ]]; then
        echo "PR #$PR_NUMBER successfully merged!"
    else
        echo "Failed to merge PR #$PR_NUMBER."
        exit 1
    fi
}

# Main
create_pr
wait_for_checks
merge_pr
