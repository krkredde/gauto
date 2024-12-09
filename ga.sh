#!/bin/bash

# Configuration variables
GITHUB_TOKEN="YOUR_GITHUB_TOKEN"    # GitHub Personal Access Token (replace with your token)
REPO_OWNER="your-username"          # GitHub repository owner (your username or org name)
REPO_NAME="your-repo"               # GitHub repository name
BRANCH_NAME="auto_merge"            # The branch name you want to create the PR from
BASE_BRANCH="main"                  # The base branch to merge into (usually 'main')
PR_TITLE="Automated PR to main"     # PR Title
PR_BODY="This PR is automatically created and merged from the auto_merge branch."
GRAPHQL_API="https://api.github.com/graphql"

# Function to run GraphQL queries
graphql_request() {
  local query="$1"
  curl -s -X POST -H "Authorization: bearer $GITHUB_TOKEN" \
       -H "Content-Type: application/json" \
       --data "{\"query\": \"$query\"}" \
       $GRAPHQL_API
}

# Step 1: Create Pull Request using GraphQL Mutation
echo "Creating PR from '$BRANCH_NAME' to '$BASE_BRANCH'..."
create_pr_query=$(cat <<EOF
mutation {
  createPullRequest(input: {
    title: "$PR_TITLE",
    body: "$PR_BODY",
    headRefName: "$BRANCH_NAME",
    baseRefName: "$BASE_BRANCH",
    repositoryId: "$(graphql_request '{
      query { 
        repository(owner: "$REPO_OWNER", name: "$REPO_NAME") {
          id
        }
      }
    }' | jq -r '.data.repository.id')"
  }) {
    pullRequest {
      url
      id
      number
    }
  }
}
EOF
)

pr_response=$(graphql_request "$create_pr_query")
PR_URL=$(echo "$pr_response" | jq -r '.data.createPullRequest.pullRequest.url')
PR_ID=$(echo "$pr_response" | jq -r '.data.createPullRequest.pullRequest.id')
PR_NUMBER=$(echo "$pr_response" | jq -r '.data.createPullRequest.pullRequest.number')

echo "Pull Request created: $PR_URL"

# Step 2: Monitor CI status (checks) on the PR
echo "Waiting for CI checks to pass on PR: $PR_URL..."

check_status_query=$(cat <<EOF
{
  "query": "
    query {
      node(id: \"$PR_ID\") {
        ... on PullRequest {
          commits(last: 1) {
            edges {
              node {
                commit {
                  statusCheckRollup {
                    state
                    contexts(first: 10) {
                      edges {
                        node {
                          name
                          status {
                            state
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  "
}
EOF
)

# Polling the CI checks until all checks are successful
check_ci_status() {
  checks_response=$(graphql_request "$check_status_query")
  check_status=$(echo "$checks_response" | jq -r '.data.node.commits.edges[0].node.commit.statusCheckRollup.state')
  
  if [ "$check_status" == "SUCCESS" ]; then
    echo "All checks have passed."
    return 0
  else
    echo "Checks are still in progress or failed. Waiting..."
    return 1
  fi
}

# Poll for CI status every 30 seconds until all checks pass
while true; do
  check_ci_status
  if [ $? -eq 0 ]; then
    break
  fi
  sleep 30
done

# Step 3: Merge the Pull Request once all checks pass
echo "Merging PR #$PR_NUMBER..."
merge_pr_query=$(cat <<EOF
mutation {
  mergePullRequest(input: {
    pullRequestId: "$PR_ID"
    commitHeadline: "Merging PR"
    mergeMethod: MERGE
  }) {
    pullRequest {
      id
      state
    }
  }
}
EOF
)

merge_response=$(graphql_request "$merge_pr_query")

# Verify if the merge was successful
merge_status=$(echo "$merge_response" | jq -r '.data.mergePullRequest.pullRequest.state')

if [ "$merge_status" == "MERGED" ]; then
  echo "Pull request #$PR_NUMBER successfully merged into $BASE_BRANCH."
else
  echo "Error: PR merge failed."
fi
