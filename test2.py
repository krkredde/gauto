import os
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
    # Retrieve the environment variables
    head_branch = os.getenv('branch')  # Fetches the 'branch' environment variable
    base_branch = os.getenv('originalBranch')  # Fetches the 'originalBranch' environment variable

    # Check if the environment variables are set
    if not head_branch or not base_branch:
        print("Error: Environment variables 'branch' or 'originalBranch' are not set.")
        exit(1)

    # Print the values of the environment variables (for debugging)
    print(f"Using head branch: {head_branch}")
    print(f"Using base branch: {base_branch}")

    # Create a PR with the head and base branches from environment variables
    pr_number, commit_sha = create_pull_request(
        title="Automated Merge PR",
        body=f"This is an automated pull request to merge '{head_branch}' into '{base_branch}'.",
        head_branch=head_branch,  # Source branch (from env)
        base_branch=base_branch   # Target branch (from env)
    )

    # If PR was created successfully, get its check run status
    if pr_number and commit_sha:
        check_runs = get_check_runs_for_commit(commit_sha)

        if check_runs:
            # Initialize variables to track the statuses of the required checks
            tenant_config_status = None
            md_validator_status = None
            file_access_status = None
            md_linter_status = None

            # Iterate over the check runs to find the specific ones
            for check in check_runs:
                check_name = check['name']
                conclusion = check.get('conclusion', 'Not completed yet')  # Default if conclusion is missing

                # Print the name and conclusion of each check run (for debugging purposes)
                print(f"Check Name: {check_name}, Conclusion: {conclusion}")

                # Check if the specific checks are successful
                if check_name == "Tenant-config-action":
                    tenant_config_status = conclusion
                elif check_name == "MD-validator-Action":
                    md_validator_status = conclusion
                elif check_name == "File-Access-Action":
                    file_access_status = conclusion
                elif check_name == "MD-Linter-Action":
                    md_linter_status = conclusion

            # Print the current status of the required checks
            if tenant_config_status:
                print(f"\nStatus of 'Tenant-config-action': {tenant_config_status}")
            if md_validator_status:
                print(f"Status of 'MD-validator-Action': {md_validator_status}")
            if file_access_status:
                print(f"Status of 'File-Access-Action': {file_access_status}")
            if md_linter_status:
                print(f"Status of 'MD-Linter-Action': {md_linter_status}")

            # Only merge if all the required checks are successful
            if tenant_config_status == "success" and md_validator_status == "success" and file_access_status == "success" and md_linter_status == "success":
                merge_pull_request(pr_number)
            else:
                print("\nRequired checks have not passed. PR will not be merged.")
                if tenant_config_status != "success":
                    print(" - 'Tenant-config-action' check failed.")
                if md_validator_status != "success":
                    print(" - 'MD-validator-Action' check failed.")
                if file_access_status != "success":
                    print(" - 'File-Access-Action' check failed.")
                if md_linter_status != "success":
                    print(" - 'MD-Linter-Action' check failed.")
