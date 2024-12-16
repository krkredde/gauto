#!/bin/bash

# GitHub settings (set your GitHub details)
GITHUB_TOKEN="your_github_token_here"
GITHUB_USER="krkredde"
REPO_NAME="gauto"
BASE_BRANCH="main"         # The branch you're merging into (usually 'main')
FEATURE_BRANCH="auto_merge" # The branch containing your changes
PR_TITLE="Auto PR Title"
PR_BODY="Auto-generated PR description"

# GitHub GraphQL API URL
GITHUB_API_URL="https://api.github.com/graphql"

# GraphQL query template for getting status checks
STATUS_CHECKS_QUERY='{
  "query": "{
    repository(owner: \"'$GITHUB_USER'\", name: \"'$REPO_NAME'\") {
      pullRequest(number: '$PR_ID') {
        id
        statusCheckRollup {
          state
          contexts {
            state
            description
            targetUrl
          }
        }
      }
    }"
}'

# Create a Pull Request
create_pr() {
    echo "Creating pull request from branch '$FEATURE_BRANCH' to '$BASE_BRANCH'..."

    PR_RESPONSE=$(curl -s -X POST \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        -d @- "$GITHUB_API_URL" <<EOF
{
  "query": "mutation {
    createPullRequest(input: {
      baseRefName: \"$BASE_BRANCH\",
      headRefName: \"$FEATURE_BRANCH\",
      title: \"$PR_TITLE\",
      body: \"$PR_BODY\"
    }) {
      pullRequest {
        id
        number
        url
      }
    }
  }"
}
EOF
    )

    # Extract PR details from the response
    PR_URL=$(echo "$PR_RESPONSE" | grep -o '"url": "[^"]*' | sed 's/"url": "//')
    PR_ID=$(echo "$PR_RESPONSE" | grep -o '"number": [0-9]*' | awk '{print $2}')

    if [[ -z "$PR_URL" || -z "$PR_ID" ]]; then
        echo "Failed to create PR. Response: $PR_RESPONSE"
        exit 1
    fi

    echo "Pull request created successfully: $PR_URL"
}

# Fetch PR check statuses using GraphQL
get_pr_checks() {
    echo "Getting status of checks for PR #$PR_ID..."

    CHECKS_RESPONSE=$(curl -s -X POST \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        -d "$STATUS_CHECKS_QUERY" "$GITHUB_API_URL")

    # Extract check status rollup state
    ROLLOVER_STATE=$(echo "$CHECKS_RESPONSE" | grep -o '"state": "[^"]*' | awk '{print $2}' | tr -d '"')
    
    # Check status for individual checks
    echo "$CHECKS_RESPONSE" | grep -o '"contexts": \[[^]]*\]' | sed 's/.*state": "\(.*\)".*/\1/'
    
    # Display aggregated state (rollup)
    echo "Overall Check State: $ROLLOVER_STATE"
}

# Wait for all checks to complete
wait_for_checks_to_complete() {
    echo "Waiting for all checks to complete for PR #$PR_ID..."

    while true; do
        get_pr_checks

        # If all checks are successful or failed, break the loop
        if [[ "$ROLLOVER_STATE" == "SUCCESS" ]]; then
            echo "All checks passed for PR #$PR_ID. Proceeding to merge."
            break
        elif [[ "$ROLLOVER_STATE" == "FAILURE" ]]; then
            echo "Some checks failed for PR #$PR_ID. Aborting merge."
            exit 1
        fi

        echo "Waiting 10 seconds before checking again..."
        sleep 10
    done
}

# Merge the Pull Request
merge_pr() {
    echo "Merging PR #$PR_ID..."

    MERGE_RESPONSE=$(curl -s -X POST \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        -d @- "$GITHUB_API_URL" <<EOF
{
  "query": "mutation {
    mergePullRequest(input: {
      pullRequestId: \"$PR_ID\",
      commitMessage: \"Merging PR #$PR_ID\"
    }) {
      pullRequest {
        id
        merged
      }
    }
  }"
}
EOF
    )

    MERGE_STATUS=$(echo "$MERGE_RESPONSE" | grep -o '"merged": [a-z]*' | awk '{print $2}' | tr -d '"')

    if [[ "$MERGE_STATUS" == "true" ]]; then
        echo "Pull request #$PR_ID merged successfully."
    else
        echo "Failed to merge PR #$PR_ID. Response: $MERGE_RESPONSE"
        exit 1
    fi
}

# Main script execution
create_pr
wait_for_checks_to_complete
merge_pr
