#!/bin/bash

# Configuration
GITHUB_TOKEN="your_github_token"
GITHUB_OWNER="krkredde"
GITHUB_REPO="gauto"
SOURCE_BRANCH="auto_merge"
TARGET_BRANCH="main"  # Or the branch you want to merge into
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

    # Extract the PR URL and number from the response
    PR_URL=$(echo "$PR_RESPONSE" | grep -o '"url": "[^"]*' | cut -d '"' -f 4)
    PR_NUMBER=$(echo "$PR_URL" | awk -F'/' '{print $NF}')
    echo "Pull request created: $PR_URL"
}

# Step 2: Check if all check runs have passed using `allow_auto_merge`
check_all_checks_passed() {
    echo "Checking status of all check runs for PR #$PR_NUMBER..."

    while true; do
        # Fetch the check runs for the PR
        CHECK_RUNS=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
            "$API_URL/repos/$GITHUB_OWNER/$GITHUB_REPO/pulls/$PR_NUMBER/checks")

        # Print the check runs for debugging
        echo "Check Runs Response: $CHECK_RUNS"

        # Look for status of the checks
        STATUS=$(echo "$CHECK_RUNS" | grep -o '"status": "[^"]*' | cut -d '"' -f 4)
        CONCLUSION=$(echo "$CHECK_RUNS" | grep -o '"conclusion": "[^"]*' | cut -d '"' -f 4)

        # Check if all checks are completed and passed
        ALL_CHECKS_PASSED=true
        for status in $STATUS; do
            if [[ "$status" != "completed" ]]; then
                ALL_CHECKS_PASSED=false
                break
            fi
        done

        for conclusion in $CONCLUSION; do
            if [[ "$conclusion" != "success" && "$conclusion" != "neutral" ]]; then
                ALL_CHECKS_PASSED=false
                break
            fi
        done

        if [ "$ALL_CHECKS_PASSED" == "true" ]; then
            echo "All checks passed and are complete."
            break
        else
            echo "Checks still pending or failed. Waiting..."
            sleep 10  # Wait for 10 seconds before checking again
        fi
    done
}

# Step 3: Enable Auto Merge (allow_auto_merge) if checks passed
enable_auto_merge() {
    echo "Enabling auto merge for PR #$PR_NUMBER..."
    MERGE_RESPONSE=$(curl -s -X PUT "$API_URL/repos/$GITHUB_OWNER/$GITHUB_REPO/pulls/$PR_NUMBER/merge" \
        -H "Authorization: token $GITHUB_TOKEN" \
        -d '{"merge_method": "merge", "allow_auto_merge": true}')

    # Check if the merge was successful
    MERGE_STATUS=$(echo "$MERGE_RESPONSE" | grep -o '"merged": [^,]*' | cut -d ':' -f 2 | tr -d '[:space:]')
    
    if [[ "$MERGE_STATUS" == "true" ]]; then
        echo "PR #$PR_NUMBER successfully merged!"
    else
        echo "Failed to merge PR #$PR_NUMBER."
        exit 1
    fi
}

# Main Execution
create_pr
check_all_checks_passed
enable_auto_merge
