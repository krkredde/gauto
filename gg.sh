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

# GraphQL query to create a pull request
create_pr() {
  echo "Creating PR from '$BRANCH_NAME' to '$BASE_BRANCH'..."

  create_pr_query=$(cat <<EOF
{
  "query": "mutation {
    createPullRequest(input: {
      baseRefName: \"$BASE_BRANCH\",
      headRefName: \"$BRANCH_NAME\",
      title: \"$PR_TITLE\",
      body: \"$PR_BODY\",
      repositoryId: \"REPO_ID\"
    }) {
      pullRequest {
        number
        url
        state
        title
      }
    } 
  }"
}
EOF
)

  # Replace REPO_ID with the actual repository ID fetched from GitHub
  repo_id=$(get_repo_id)
  create_pr_query=$(echo "$create_pr_query" | sed "s/REPO_ID/$repo_id/")

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

# Function to fetch repository ID using GraphQL
get_repo_id() {
  repo_query=$(cat <<EOF
{
  "query": "{
    repository(owner: \"$REPO_OWNER\", name: \"$REPO_NAME\") {
      id
    }
  }"
}
EOF
)

  repo_response=$(curl -s -X POST -H "Authorization: Bearer $GITHUB_TOKEN" -H "Content-Type: application/json" -d "$repo_query" "$GRAPHQL_API_URL")
  REPO_ID=$(echo "$repo_response" | grep -o '"id":\s*"[^"]*' | sed 's/"id": "//')

  if [ -z "$REPO_ID" ]; then
    echo "Error: Failed to fetch repository ID."
    exit 1
  fi

  echo "$REPO_ID"
}

# Function to get the status of checks for a specific commit in a PR
get_check_status() {
  commit_sha=$1

  checks_query=$(cat <<EOF
{
  "query": "{
    repository(owner: \"$REPO_OWNER\", name: \"$REPO_NAME\") {
      object(expression: \"$commit_sha\") {
        ... on Commit {
          checkSuites(first: 10) {
            edges {
              node {
                status
                conclusion
                checkRuns(first: 10) {
                  edges {
                    node {
                      name
                      status
                      conclusion
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }"
}
EOF
)

  check_runs_response=$(curl -s -X POST -H "Authorization: Bearer $GITHUB_TOKEN" -H "Content-Type: application/json" -d "$checks_query" "$GRAPHQL_API_URL")

  # Extract check statuses from response
  check_names=$(echo "$check_runs_response" | grep -o '"name":\s*"[^"]*' | sed 's/"name": "//')
  check_statuses=$(echo "$check_runs_response" | grep -o '"status":\s*"[^"]*' | sed 's/"status": "//')
  check_conclusions=$(echo "$check_runs_response" | grep -o '"conclusion":\s*"[^"]*' | sed 's/"conclusion": "//')

  successful_count=0
  failing_count=0
  in_progress_count=0
  queued_count=0
  total_checks=0

  # Classify and count check statuses
  count=0
  all_checks_completed=true

  for check_name in $check_names; do
    status=$(echo "$check_statuses" | sed -n "$((count + 1))p")
    conclusion=$(echo "$check_conclusions" | sed -n "$((count + 1))p")

    echo "Check: $check_name"
    echo "Status: $status"
    echo "Conclusion: $conclusion"
    echo "-----"

    total_checks=$((total_checks + 1))

    if [ "$status" == "IN_PROGRESS" ] || [ "$status" == "QUEUED" ]; then
      all_checks_completed=false
      queued_count=$((queued_count + 1))
    elif [ "$conclusion" == "SUCCESS" ]; then
      successful_count=$((successful_count + 1))
    elif [ "$conclusion" == "FAILURE" ] || [ "$conclusion" == "NEUTRAL" ]; then
      failing_count=$((failing_count + 1))
    fi

    count=$((count + 1))
  done

  echo "Summary of Checks:"
  echo "Total Checks: $total_checks"
  echo "Successful Checks: $successful_count"
  echo "Failing Checks: $failing_count"
  echo "In Progress Checks: $in_progress_count"
  echo "Queued Checks: $queued_count"

  if [ "$all_checks_completed" == false ]; then
    echo "Checks are still in progress or queued. Waiting..."
    return 1
  fi

  if [ "$successful_count" -eq "$total_checks" ]; then
    echo "All checks have passed."
    return 0
  else
    echo "Not all checks have passed. Waiting for all checks to pass..."
    return 1
  fi
}

# Function to merge the PR after all checks pass
merge_pr() {
  echo "Merging PR #$PR_NUMBER..."

  merge_query=$(cat <<EOF
{
  "query": "mutation {
    mergePullRequest(input: {
      pullRequestId: \"$PR_ID\",
      commitTitle: \"Merging PR #$PR_NUMBER\",
      mergeMethod: MERGE
    }) {
      pullRequest {
        merged
        title
      }
    }
  }"
}
EOF
)

  pr_id=$(get_pr_id)

  # Replace PR_ID with the actual PR ID
  merge_query=$(echo "$merge_query" | sed "s/PR_ID/$pr_id/")

  merge_response=$(curl -s -X POST -H "Authorization: Bearer $GITHUB_TOKEN" -H "Content-Type: application/json" -d "$merge_query" "$GRAPHQL_API_URL")
  merged=$(echo "$merge_response" | grep -o '"merged":\s*"[^"]*' | sed 's/"merged": "//')

  if [ "$merged" == "true" ]; then
    echo "PR #$PR_NUMBER successfully merged into $BASE_BRANCH."
  else
    echo "Error: PR merge failed."
    echo "Response from GitHub API: $merge_response"
    exit 1
  fi
}

# Function to fetch PR ID from GraphQL
get_pr_id() {
  pr_query=$(cat <<EOF
{
  "query": "{
    repository(owner: \"$REPO_OWNER\", name: \"$REPO_NAME\") {
      pullRequest(number: $PR_NUMBER) {
        id
      }
    }
  }"
}
EOF
)

  pr_response=$(curl -s -X POST -H "Authorization: Bearer $GITHUB_TOKEN" -H "Content-Type: application/json" -d "$pr_query" "$GRAPHQL_API_URL")
  PR_ID=$(echo "$pr_response" | grep -o '"id":\s*"[^"]*' | sed 's/"id": "//')

  if [ -z "$PR_ID" ]; then
    echo "Error
