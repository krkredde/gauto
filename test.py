import requests
import json

# GitHub API base URL
GITHUB_API_URL = "https://api.github.com"

# Your GitHub credentials
GITHUB_TOKEN = "your_personal_access_token"
REPO_OWNER = "krkredde"
REPO_NAME = "gauto"

# Headers for GitHub API requests
HEADERS = {
    "Authorization": f"Bearer {GITHUB_TOKEN}",
    "Accept": "application/vnd.github.v3+json",
}

# Function to create a pull request
def create_pull_request(title, body, head_branch, base_branch):
    url = f"{GITHUB_API_URL}/repos/{REPO_OWNER}/{REPO_NAME}/pulls"
    
    # For a forked repository, ensure head is in the correct format
    if REPO_OWNER != 'your-username':
        head_branch = f"{REPO_OWNER}:{head_branch}"

    payload = {
        "title": title,
        "body": body,
        "head": head_branch,
        "base": base_branch
    }

    response = requests.post(url, headers=HEADERS, json=payload)

    if response.status_code == 201:
        pr_data = response.json()
        print(f"PR Created: {pr_data['html_url']}")
        return pr_data['number'], pr_data['head']['sha']  # Return PR number and commit SHA
    else:
        print(f"Error creating PR: {response.status_code}, {response.text}")
        return None, None

# Function to get check runs for the commit associated with the PR
def get_check_runs_for_commit(commit_sha):
    url = f"{GITHUB_API_URL}/repos/{REPO_OWNER}/{REPO_NAME}/commits/{commit_sha}/check-runs"
    response = requests.get(url, headers=HEADERS)

    if response.status_code == 200:
        check_runs = response.json().get("check_runs", [])
        if not check_runs:
            print("No check runs found for this commit.")
            return []

        print("\nAll Check Runs for Commit:")
        # Display all check runs
        for check in check_runs:
            print(f"- {check['name']} ({check['status']}) - Conclusion: {check['conclusion']}")

        return check_runs
    else:
        print(f"Error fetching check runs: {response.status_code}, {response.text}")
        return []

# Function to merge the pull request
def merge_pull_request(pr_number):
    url = f"{GITHUB_API_URL}/repos/{REPO_OWNER}/{REPO_NAME}/pulls/{pr_number}/merge"
    payload = {
        "commit_title": "Merging PR automatically after successful checks",
        "merge_method": "merge"  # Options: merge, squash, rebase
    }

    response = requests.put(url, headers=HEADERS, json=payload)

    if response.status_code == 200:
        print(f"PR #{pr_number} has been successfully merged!")
    else:
        print(f"Error merging PR: {response.status_code}, {response.text}")

# Example usage
if __name__ == "__main__":
    # Create a PR with the 'auto_merge' branch as the source and 'main' as the target
    pr_number, commit_sha = create_pull_request(
        title="Automated Merge PR",
        body="This is an automated pull request to merge 'auto_merge' into 'main'.",
        head_branch="auto_merge",  # Source branch
        base_branch="main"         # Target branch
    )

    # If PR was created successfully, get its check run status
    if pr_number and commit_sha:
        check_runs = get_check_runs_for_commit(commit_sha)

        if check_runs:
            # Condition to check if both 'Run npm on Ubuntu' and 'build' are successful
            npm_status = None
            build_status = None

            for check in check_runs:
                check_name = check['name']
                conclusion = check['conclusion']

                # Check if the specific checks are successful
                if check_name == "Run npm on Ubuntu":
                    npm_status = conclusion
                elif check_name == "build":
                    build_status = conclusion

            # Print the current status of required checks
            if npm_status:
                print(f"\nStatus of 'Run npm on Ubuntu': {npm_status}")
            if build_status:
                print(f"Status of 'build': {build_status}")

            # Only merge if both checks are successful
            if npm_status == "success" and build_status == "success":
                merge_pull_request(pr_number)
            else:
                print("\nRequired checks have not passed. PR will not be merged.")
                if npm_status != "success":
                    print(" - 'Run npm on Ubuntu' check failed.")
                if build_status != "success":
                    print(" - 'build' check failed.")

#output

# PR Created: https://github.com/krkredde/gauto/pull/57

# All Check Runs for Commit:
# - Run npm on Ubuntu (completed) - Conclusion: success
# - build (completed) - Conclusion: success
# - Run PSScriptAnalyzer on Windows (completed) - Conclusion: success

# Status of 'Run npm on Ubuntu': success
# Status of 'build': success
# PR #57 has been successfully merged!


import time

# # Function to get check runs for the commit associated with the PR (with retry)
# def get_check_runs_for_commit(commit_sha, retries=10, delay=5):
#     url = f"{GITHUB_API_URL}/repos/{REPO_OWNER}/{REPO_NAME}/commits/{commit_sha}/check-runs"
    
#     for _ in range(retries):
#         response = requests.get(url, headers=HEADERS)

#         if response.status_code == 200:
#             check_runs = response.json().get("check_runs", [])
#             if not check_runs:
#                 print("No check runs found for this commit.")
#             else:
#                 # Remove duplicate check runs based on the 'name' of the check run
#                 unique_check_runs = {}
#                 for check in check_runs:
#                     check_name = check['name']
#                     if check_name not in unique_check_runs:
#                         unique_check_runs[check_name] = check

#                 # Display the unique check runs
#                 print("\nUnique Check Runs for Commit:")
#                 for check in unique_check_runs.values():
#                     print(f"- {check['name']} ({check['status']}) - Conclusion: {check['conclusion']}")
#             break  # Exit the loop if check runs are found and processed
#         else:
#             print(f"Error fetching check runs: {response.status_code}, {response.text}")
        
#         # Wait before retrying
#         print(f"Waiting {delay} seconds before retrying...")
#         time.sleep(delay)
#     else:
#         print(f"Failed to get check runs after {retries} retries.")


