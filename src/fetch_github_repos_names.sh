#!/bin/bash
set -euo pipefail

# Script Name: fetch_github_repos_names.sh
# Description: Fetches and lists all repositories of a GitHub user.
#              Lists both public and private repositories if a personal access token is provided.
# Usage: ./fetch_github_repos_names.sh [github_username] [github_token]
# Example: ./fetch_github_repos_names.sh johnsmith YOUR_GITHUB_TOKEN

# Display usage message and exit
usage() {
    echo "Usage: $0 [github_username] [github_token]"
    echo "  github_username - Optional. GitHub username to fetch repositories for."
    echo "  github_token    - Optional. Personal access token to access private repositories."
    exit 1
}

echo "GitHub Repository Fetcher"

# Check if jq is installed
check_jq_installed() {
    if ! command -v jq &>/dev/null; then
        echo "Error: jq is not installed. Please install jq to run this script."
        exit 1
    fi
}

# Get authenticated user's login using provided token
get_authenticated_user() {
    local token="$1"
    local auth_header="Authorization: token $token"
    local user_login
    user_login=$(curl -s -H "$auth_header" https://api.github.com/user | jq -r '.login')
    echo "$user_login"
}

# Global variable for authorization header (set in main)
auth_header=""

# Fetch a page with a single curl call to get both headers and body
# The function echoes the body and sets the global variable 'next_url' if more pages exist.
fetch_page() {
    local url="$1"
    # Fetch headers and body together
    local response
    response=$(curl -s -D - "$url" -H "$auth_header")
    # Separate headers (everything until the first blank line)
    local header
    header=$(printf "%s" "$response" | sed -n '1,/^$/p')
    # Separate body (everything after the first blank line)
    local body
    body=$(printf "%s" "$response" | sed -n '/^$/,$p' | sed '1d')
    # Extract next page URL from the Link header, if available
    if [[ "$header" =~ \<([^>]+)\>\;\ *rel=\"next\" ]]; then
        next_url="${BASH_REMATCH[1]}"
    else
        next_url=""
    fi
    echo "$body"
}

# Main function
main() {
    check_jq_installed

    if [ "$#" -gt 2 ]; then
        usage
    fi

    local USERNAME="${1:-}"
    local GITHUB_TOKEN="${2:-}"
    local AUTHENTICATED_USER=""

    if [ -n "$GITHUB_TOKEN" ]; then
        auth_header="Authorization: token $GITHUB_TOKEN"
        AUTHENTICATED_USER=$(get_authenticated_user "$GITHUB_TOKEN")
        if [ -z "$AUTHENTICATED_USER" ] || [ "$AUTHENTICATED_USER" = "null" ]; then
            echo "Error: Invalid or expired GitHub token."
            exit 1
        fi
    else
        auth_header=""
    fi

    local URL=""
    # Determine API endpoint to use
    if [ -n "$GITHUB_TOKEN" ] && { [ -z "$USERNAME" ] || [ "$USERNAME" = "$AUTHENTICATED_USER" ]; }; then
        URL="https://api.github.com/user/repos?per_page=100"
        echo "Fetching repositories for authenticated user '$AUTHENTICATED_USER'..."
    elif [ -n "$USERNAME" ]; then
        URL="https://api.github.com/users/$USERNAME/repos?per_page=100"
        echo "Fetching public repositories for user '$USERNAME'..."
    else
        echo "Error: Username required if no token is provided."
        usage
    fi

    echo "--------------------------------"

    # Fetch repositories with pagination
    while [ -n "$URL" ]; do
        local page_body
        page_body=$(fetch_page "$URL")
        echo "$page_body" | jq -r '.[] | .name'
        URL="$next_url"
    done

    echo "--------------------------------"
    echo "Fetch complete."
}

main "$@"

