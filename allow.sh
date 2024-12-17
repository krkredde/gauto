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
        PR_STATUS=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
            "$API_URL/repos/$GITHUB_OWNER/$GITHUB_REPO/pulls/$PR_NUMBER")

        # Check the entire PR status for debugging
        echo "PR Status Response: $PR_STATUS"

        # Get mergeable status
        MERGEABLE=$(echo "$PR_STATUS" | grep -o '"mergeable": [^,]*' | cut -d ':' -f 2 | tr -d '[:space:]')

        # Check if there are failing checks
        CHECK_STATUS=$(echo "$PR_STATUS" | grep -o '"state": "[^"]*' | cut -d '"' -f 4)
        echo "Status of checks: $CHECK_STATUS"

        if [[ "$MERGEABLE" == "true" ]]; then
            echo "PR #$PR_NUMBER is mergeable!"
            break
        elif [[ "$MERGEABLE" == "false" ]]; then
            echo "PR #$PR_NUMBER is not mergeable due to conflicts or failed checks."
            exit 1
        elif [[ "$MERGEABLE" == "null" ]]; then
            echo "PR #$PR_NUMBER is still being processed or there are unresolved conflicts."
            sleep 10  # Wait for 10 seconds before checking again
        else
            echo "Unexpected mergeable value: $MERGEABLE. Exiting."
            exit 1
        fi
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
