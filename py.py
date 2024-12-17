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
        return pr_data['number']
    else:
        print(f"Error creating PR: {response.status_code}, {response.text}")
        return None

# Function to get check runs for a pull request
def get_check_runs_for_pr(pr_number):
    url = f"{GITHUB_API_URL}/repos/{REPO_OWNER}/{REPO_NAME}/pulls/{pr_number}/check-runs"
    response = requests.get(url, headers=HEADERS)

    if response.status_code == 200:
        check_runs = response.json().get("check_runs", [])
        if not check_runs:
            print("No check runs found for this PR.")
        else:
            print("Check Runs for PR:")
            for check in check_runs:
                print(f"- {check['name']}: {check['status']} - {check['conclusion']}")
    else:
        print(f"Error fetching check runs: {response.status_code}, {response.text}")

# Example usage
if __name__ == "__main__":
    # Create a PR (Modify as per your use case)
    pr_number = create_pull_request(
        title="New feature implementation",
        body="This PR adds a new feature to the project.",
        head_branch="feature-branch",  # Your feature branch name
        base_branch="main"             # The base branch (usually main or master)
    )
    
    # If PR was created successfully, get its check run status
    if pr_number:
        get_check_runs_for_pr(pr_number)
