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
#!/bin/bash

# Step 1: Create the PR
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

    PR_URL=$(echo "$PR_RESPONSE" | grep -o '"url": "[^"]*' | cut -d '"' -f 4)
    PR_NUMBER=$(echo "$PR_URL" | awk -F'/' '{print $NF}')
    echo "Pull request created: $PR_URL"
}

# Step 2: Check the mergeability status
check_mergeability() {
    PR_STATUS=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "$API_URL/repos/$GITHUB_OWNER/$GITHUB_REPO/pulls/$PR_NUMBER")

    MERGEABLE=$(echo "$PR_STATUS" | grep -o '"mergeable": [^,]*' | cut -d ':' -f 2 | tr -d '[:space:]')

    if [[ "$MERGEABLE" == "true" ]]; then
        echo "PR #$PR_NUMBER is mergeable!"
    elif [[ "$MERGEABLE" == "false" ]]; then
        echo "PR #$PR_NUMBER has merge conflicts or failed checks."
        exit 1
    else
        echo "PR #$PR_NUMBER is still being processed."
        exit 1
    fi
}

# Step 3: Check if all checks passed
check_all_checks_passed() {
    CHECK_RUNS=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "$API_URL/repos/$GITHUB_OWNER/$GITHUB_REPO/pulls/$PR_NUMBER/checks")

    STATUS=$(echo "$CHECK_RUNS" | grep -o '"status": "[^"]*' | cut -d '"' -f 4)
    CONCLUSION=$(echo "$CHECK_RUNS" | grep -o '"conclusion": "[^"]*' | cut -d '"' -f 4)

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
    else
       
# Main Execution
create_pr
check_all_checks_passed
enable_auto_merge
