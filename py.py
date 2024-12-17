import requests
import json

# GitHub API base URL
GITHUB_API_URL = "https://api.github.com"

# Your GitHub credentials
GITHUB_TOKEN = "your_personal_access_token"
REPO_OWNER = "your_github_username_or_org"
REPO_NAME = "your_repo_name"

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
            print("\nCheck Runs for PR:")
            for check in check_runs:
                # Display the check name, status, and conclusion
                print(f"- {check['name']} ({check['status']}) - Conclusion: {check['conclusion']}")
    else:
        print(f"Error fetching check runs: {response.status_code}, {response.text}")

# Example usage
if __name__ == "__main__":
    # Create a PR with the 'auto_merge' branch as the source and 'main' as the target
    pr_number = create_pull_request(
        title="Automated Merge PR",
        body="This is an automated pull request to merge 'auto_merge' into 'main'.",
        head_branch="auto_merge",  # Source branch
        base_branch="main"         # Target branch
    )

    # If PR was created successfully, get its check run status
    if pr_number:
        get_check_runs_for_pr(pr_number)
