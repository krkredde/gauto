#!/bin/bash

# Set these values
GITHUB_TOKEN="your_github_token_here"
GITHUB_USER="your_github_username"
REPO_NAME="your_repo_name"
BASE_BRANCH="main"           # The branch you're merging into (usually 'main')
FEATURE_BRANCH="feature-branch" # The branch containing your changes
PR_TITLE="Auto PR Title"
PR_BODY="Auto-generated PR description"

# GitHub API URL
API_URL="https://api.github.com"

# Create a Pull Request
create_pr() {
    echo "Creating pull request from branch '$FEATURE_BRANCH' to '$BASE_BRANCH'..."

    # Create the PR via GitHub API
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

    # Extract PR details
    PR_URL=$(echo $PR_RESPONSE | jq -r .html_url)
    PR_ID=$(echo $PR_RESPONSE | jq -r .number)

    if [[ "$PR_URL" == "null" ]]; then
        echo "Failed to create PR. Response: $PR_RESPONSE"
        exit 1
    fi

    echo "Pull request created successfully: $PR_URL"
}

# Get PR Checks (CI/CD) status
get_pr_checks() {
    echo "Getting status of checks for PR #$PR_ID..."

    # Get the PR status (including checks)
    CHECKS_RESPONSE=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "$API_URL/repos/$GITHUB_USER/$REPO_NAME/pulls/$PR_ID/statuses")

    # Parse the statuses of each check (success or failure)
    CHECKS=$(echo $CHECKS_RESPONSE | jq -r '.[].state')

    if [[ -z "$CHECKS" ]]; then
        echo "No checks found for PR #$PR_ID."
        return
    fi

    SUCCESS_COUNT=0
    FAILURE_COUNT=0
    PENDING_COUNT=0

    for state in $CHECKS; do
        if [[ "$state" == "success" ]]; then
            ((SUCCESS_COUNT++))
        elif [[ "$state" == "failure" ]]; then
            ((FAILURE_COUNT++))
        elif [[ "$state" == "pending" ]]; then
            ((PENDING_COUNT++))
        fi
    done

    # Display status
    echo "Check Status for PR #$PR_ID:"
    echo "Successful checks: $SUCCESS_COUNT"
    echo "Failed checks: $FAILURE_COUNT"
    echo "Pending checks: $PENDING_COUNT"
}

# Wait for checks to complete
wait_for_checks_to_complete() {
    echo "Waiting for all checks to complete for PR #$PR_ID..."

    while true; do
        get_pr_checks

        # If all checks are successful or failed, break the loop
        if [[ "$PENDING_COUNT" -eq 0 ]]; then
            if [[ "$FAILURE_COUNT" -eq 0 ]]; then
                echo "All checks passed for PR #$PR_ID. Proceeding to merge."
                break
            else
                echo "Some checks failed for PR #$PR_ID. Aborting merge."
                exit 1
            fi
        fi

        echo "Waiting 10 seconds before checking again..."
        sleep 10
    done
}

# Merge the Pull Request
merge_pr() {
    echo "Merging PR #$PR_ID..."

    MERGE_RESPONSE=$(curl -s -X PUT \
        -H "Authorization: token $GITHUB_TOKEN" \
        -d @- "$API_URL/repos/$GITHUB_USER/$REPO_NAME/pulls/$PR_ID/merge" <<EOF
{
  "commit_title": "Merge pull request #$PR_ID",
  "commit_message": "Merging PR #$PR_ID into $BASE_BRANCH",
  "merge_method": "merge"  # Options: merge, squash, rebase
}
EOF
    )

    MERGE_STATUS=$(echo $MERGE_RESPONSE | jq -r .merged)

    if [[ "$MERGE_STATUS" == "true" ]]; then
        echo "Pull request #$PR_ID merged successfully."
    else
        echo "Failed to merge PR #$PR_ID. Response: $MERGE_RESPONSE"
        exit 1
    fi
}

# Main script execution
create_pr
get_pr_checks        # Display checks immediately after PR creation
wait_for_checks_to_complete
merge_pr
