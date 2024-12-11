#!/bin/bash

# Configuration variables
GITHUB_TOKEN="YOUR_GITHUB_TOKEN"    # Replace with your GitHub Personal Access Token
REPO_OWNER="krkredde"               # Replace with the GitHub repository owner
REPO_NAME="gauto"                   # Replace with the GitHub repository name
BRANCH_NAME="auto_merge"            # Replace with your feature branch
BASE_BRANCH="main"                  # The base branch to merge into (usually 'main')
PR_TITLE="Automated PR to main"     # The title of the PR
PR_BODY="This PR is automatically created and merged from the auto_merge branch."
ALLOW_AUTO_MERGE=true               # Set to true to auto-merge when checks pass, false to disable
GRAPHQL_API_URL="https://api.github.com/graphql"

# Function to fetch repository ID using GraphQL
get_repo_id() {
  echo "Fetching repository ID for $REPO_OWNER/$REPO_NAME..."

  repo_query='{
    "query": "{
      repository(owner: \"'"$REPO_OWNER"'\", name: \"'"$REPO_NAME"'\") {
        id
      }
    }"
  }'

  repo_response=$(curl -s -X POST -H "Authorization: Bearer $GITHUB_TOKEN" -H "Content-Type: application/json" -d "$repo_query" "$GRAPHQL_API_URL")

  REPO_ID=$(echo "$repo_response" | grep -o '"id":\s*"[^"]*' | sed 's/"id": "//')

  if [ -z "$REPO_ID" ]; then
    echo "Error: Failed to fetch repository ID."
    exit 1
  fi

  echo "Repository ID: $REPO_ID"
}

# Function to create Pull Request using GraphQL
create_pr() {
  echo "Creating PR from '$BRANCH_NAME' to '$BASE_BRANCH'..."

  create_pr_query='{
    "query": "mutation {
      createPullRequest(input: {
        baseRefName: \"'"$BASE_BRANCH"'\", 
        headRefName: \"'"$BRANCH_NAME"'\", 
        title: \"'"$PR_TITLE"'\", 
        body: \"'"$PR_BODY"'\", 
        repositoryId: \"'"$REPO_ID"'\" 
      }) {
        pullRequest {
          number
          url
          state
          title
        }
      }
    }"
  }'

  pr_response=$(curl -s -X POST -H "Authorization: Bearer $GITHUB_TOKEN" -H "Content-Type: application/json" -d "$create_pr_query" "$GRAPHQL_API_URL")

  PR_URL=$(echo "$pr_response" | grep -o '"url":\s*"[^"]*' | sed 's/"url": "//')
  PR_NUMBER=$(echo "$pr_response" | grep -o '"number":\s*[0-9]*' | sed 's/"number": //')

  if [ -z "$PR_URL" ] || [ -z "$PR_NUMBER" ]; then
    echo "Error: Failed to create Pull Request."
    echo "Response from GitHub API: $pr_response"
    exit 1
  fi

  echo "Pull Request created: $PR_URL"
}

# Main execution
get_repo_id
create_pr

