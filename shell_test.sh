#!/bin/bash

# GitHub API base URL
GITHUB_API_URL="https://api.github.com"

# GitHub credentials
GITHUB_TOKEN="your_personal_access_token"
REPO_OWNER="krkredde"
REPO_NAME="gauto"

# Branch names
HEAD_BRANCH="auto_merge"
BASE_BRANCH="main"

# Create a Pull Request
create_pull_request() {
    # API endpoint for creating a PR
    url="$GITHUB_API_URL/repos/$REPO_OWNER/$REPO_NAME/pulls"

    # PR payload (json data)
    payload=$(cat <<EOF
{
  "title": "Automated Merge PR",
  "body": "This is an automated pull request to merge '$HEAD_BRANCH' into '$BASE_BRANCH'.",
  "head": "$HEAD_BRANCH",
  "base": "$BASE_BRANCH"
}
EOF
    )

    # Create PR using curl
    response=$(curl -s -X POST -H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" \
        -d "$payload" "$url")

    # Extract PR number and commit SHA from the response
    pr_number=$(echo "$response" | grep -o '"number": [0-9]\+' | awk -F': ' '{print $2}')
    commit_sha=$(echo "$response" | grep -o '"sha": "[a-f0-9]\+"' | awk -F': "' '{print $2}' | sed 's/"//g')

    if [ -z "$pr_number" ] || [ -z "$commit_sha" ]; then
        echo "Error creating PR: $response"
        exit 1
    else
        echo "PR Created: https://github.com/$REPO_OWNER/$REPO_NAME/pull/$pr_number"
        echo "Commit SHA: $commit_sha"
    fi
}

# Get Check Runs for a specific commit
get_check_runs_for_commit() {
    commit_sha="$1"
    url="$GITHUB_API_URL/repos/$REPO_OWNER/$REPO_NAME/commits/$commit_sha/check-runs"

    # Fetch check runs using curl
    response=$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" "$url")

    if [ -z "$response" ]; then
        echo "Error fetching check runs: No response from GitHub"
        exit 1
    fi

    # Extract check run names, statuses, and conclusions
    echo "All Check Runs for Commit:"
    check_runs=$(echo "$response" | grep -o '"name": "[^"]*"\|"status": "[^"]*"\|"conclusion": "[^"]*"')

    if [ -z "$check_runs" ]; then
        echo "No check runs found for this commit."
        exit 1
    fi

    echo "$check_runs" | while read -r line; do
        # Parse the name, status, and conclusion
        check_name=$(echo "$line" | grep -o '"name": "[^"]*"' | sed 's/"name": "//' | sed 's/"//g')
        status=$(echo "$line" | grep -o '"status": "[^"]*"' | sed 's/"status": "//' | sed 's/"//g')
        conclusion=$(echo "$line" | grep -o '"conclusion": "[^"]*"' | sed 's/"conclusion": "//' | sed 's/"//g')

        # Display check run information
        echo "- $check_name ($status) - Conclusion: $conclusion"

        # Check if the specific checks have been completed and their conclusions
        if [ "$check_name" == "Run npm on Ubuntu" ]; then
            npm_status="$conclusion"
        elif [ "$check_name" == "build" ]; then
            build_status="$conclusion"
        fi
    done

    # Return the check statuses for npm and build
    echo "$npm_status $build_status"
}

# Merge the Pull Request if both checks passed
merge_pull_request() {
    pr_number="$1"

    # API endpoint to merge the PR
    url="$GITHUB_API_URL/repos/$REPO_OWNER/$REPO_NAME/pulls/$pr_number/merge"

    # Merge PR using curl
    response=$(curl -s -X PUT -H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" \
        -d '{"commit_title": "Merging PR automatically after successful checks", "merge_method": "merge"}' "$url")

    # Check for merge success
    if echo "$response" | grep -q "merged\": true"; then
        echo "PR #$pr_number has been successfully merged!"
    else
        echo "Error merging PR: $response"
    fi
}

# Main process
create_pull_request

# If PR created successfully, check the check runs
if [ ! -z "$pr_number" ] && [ ! -z "$commit_sha" ]; then
    check_runs_status=$(get_check_runs_for_commit "$commit_sha")
    
    # Extract the conclusion status of 'Run npm on Ubuntu' and 'build' checks
    npm_status=$(echo "$check_runs_status" | awk '{print $1}')
    build_status=$(echo "$check_runs_status" | awk '{print $2}')

    # Only merge if both checks are successful
    if [ "$npm_status" == "success" ] && [ "$build_status" == "success" ]; then
        merge_pull_request "$pr_number"
    else
        echo "Required checks have not passed. PR will not be merged."
        if [ "$npm_status" != "success" ]; then
            echo " - 'Run npm on Ubuntu' check failed."
        fi
        if [ "$build_status" != "success" ]; then
            echo " - 'build' check failed."
        fi
    fi
fi
