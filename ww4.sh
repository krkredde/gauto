#!/bin/bash

# GitHub settings (set your GitHub details)
GITHUB_TOKEN="your_github_token_here"
GITHUB_USER="your_github_username"
REPO_NAME="your_repo_name"
BASE_BRANCH="main"         # The branch you're merging into (usually 'main')
FEATURE_BRANCH="auto_merge" # The branch containing your changes
PR_TITLE="Auto PR Title"
PR_BODY="Auto-generated PR description"

# GitHub GraphQL API URL
GITHUB_API_URL="https://api.github.com/graphql"

# Step 1: Get the repository ID using GraphQL
get_repository_id() {
    echo "Fetching repository ID..."

    REPO_ID_RESPONSE=$(curl -s -X POST \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        -d @- "$GITHUB_API_URL" <<EOF
{
  "query": "{
    repository(owner: \"$GITHUB_USER\", name: \"$REPO_NAME\") {
      id
    }
  }"
}
EOF
    )

    # Extract repositoryId from the response using jq
    REPO_ID=$(echo "$REPO_ID_RESPONSE" | jq -r '.data.repository.id')

    if [[ -z "$REPO_ID" || "$REPO_ID" == "null" ]]; then
        echo "Failed to fetch repository ID. Response: $REPO_ID_RESPONSE"
        exit 1
    fi

    echo "Repository ID: $REPO_ID"
}

# Step 2: Create the Pull Request
create_pr() {
    echo "Creating pull request from branch '$FEATURE_BRANCH' to '$BASE_BRANCH'..."

    PR_RESPONSE=$(curl -s -X POST \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        -d @- "$GITHUB_API_URL" <<EOF
{
  "query": "mutation {
    createPullRequest(input: {
      repositoryId: \"$REPO_ID\",
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

    # Extract PR details from the response using jq
    PR_URL=$(echo "$PR_RESPONSE" | jq -r '.data.createPullRequest.pullRequest.url')
    PR_ID=$(echo "$PR_RESPONSE" | jq -r '.data.createPullRequest.pullRequest.number')

    if [[ -z "$PR_URL" || -z "$PR_ID" ]]; then
        echo "Failed to create PR. Response: $PR_RESPONSE"
        exit 1
    fi

    echo "Pull request created successfully: $PR_URL"
}

# Step 3: Fetch PR check statuses using GraphQL
get_pr_checks() {
    echo "Getting status of checks for PR #$PR_ID..."

    CHECKS_RESPONSE=$(curl -s -X POST \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        -d @- "$GITHUB_API_URL" <<EOF
{
  "query": "{
    repository(owner: \"$GITHUB_USER\", name: \"$REPO_NAME\") {
      pullRequest(number: $PR_ID) {
        statusCheckRollup {
          state
          contexts {
            state
            description
            targetUrl
          }
        }
      }
    }
  }"
}
EOF
    )

    # Extract check status rollup state using jq
    ROLLOVER_STATE=$(echo "$CHECKS_RESPONSE" | jq -r '.data.repository.pullRequest.statusCheckRollup.state')

    # If statusCheckRollup is null, handle it
    if [[ "$ROLLOVER_STATE" == "null" || -z "$ROLLOVER_STATE" ]]; then
        echo "No status check rollup data found for PR #$PR_ID."
        return 1
    fi

    # If there are contexts (individual checks), display their states
    CONTEXTS=$(echo "$CHECKS_RESPONSE" | jq -r '.data.repository.pullRequest.statusCheckRollup.contexts')
    if [[ "$CONTEXTS" == "null" || -z "$CONTEXTS" ]]; then
        echo "No individual check contexts found for PR #$PR_ID."
    else
        echo "$CONTEXTS" | jq -r '.[] | "\(.state): \(.description)"'
    fi
    
    # Display aggregated state (rollup)
    echo "Overall Check State: $ROLLOVER_STATE"
}

# Wait for all checks to complete
wait_for_checks_to_complete() {
    echo "Waiting for all checks to complete for PR #$PR_ID..."

    while true; do
        get_pr_checks
        CHECK_STATUS=$?

        # If there are no checks or status is null, retry later
        if [[ $CHECK_STATUS -eq 1 ]]; then
            echo "No status checks yet for PR #$PR_ID. Retrying in 10 seconds..."
        elif [[ "$ROLLOVER_STATE" == "SUCCESS" ]]; then
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

    MERGE_STATUS=$(echo "$MERGE_RESPONSE" | jq -r '.data.mergePullRequest.pullRequest.merged')

    if [[ "$MERGE_STATUS" == "true" ]]; then
        echo "Pull request #$PR_ID merged successfully."
    else
        echo "Failed to merge PR #$PR_ID. Response: $MERGE_RESPONSE"
        exit 1
    fi
}

# Main script execution
get_repository_id
create_pr
wait_for_checks_to_complete
merge_pr
