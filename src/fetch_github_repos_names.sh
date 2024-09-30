#!/bin/bash

# Script Name: fetch_github_repos_names.sh
# Description: Fetches and lists all repositories of a GitHub user.
#              It lists both public and private repositories if a personal access token is provided.
# Usage: fetch_github_repos.sh [github_username] [github_token]
#        github_username - Optional. The GitHub username for which to fetch repositories.
#        github_token - Optional. A GitHub personal access token for accessing private repositories.
# Example: ./fetch_github_repos_names.sh johnsmith [token]

echo "GitHub Repository Fetcher"

# Function to check if jq is installed
check_jq_installed() {
    if ! command -v jq &>/dev/null; then
        echo "Error: jq is not installed. Please install jq to run this script."
        exit 1
    fi
}

# Function to get authenticated user's login
get_authenticated_user() {
    local token=$1
    local auth_header=""
    local user_login=""

    if [ -n "$token" ]; then
        auth_header="Authorization: token $token"
        user_login=$(curl -s -H "$auth_header" https://api.github.com/user | jq -r '.login')
    fi

    echo "$user_login"
}

# Main function
main() {
    check_jq_installed

    if [ "$#" -gt 2 ]; then
        echo "Usage: $0 [github_username] [github_token]"
        exit 1
    fi

    local USERNAME=${1:-}
    local GITHUB_TOKEN=${2:-}
    local AUTHENTICATED_USER=""

    if [ -n "$GITHUB_TOKEN" ]; then
        AUTHENTICATED_USER=$(get_authenticated_user "$GITHUB_TOKEN")
        if [ -z "$AUTHENTICATED_USER" ] || [ "$AUTHENTICATED_USER" = "null" ]; then
            echo "Error: Invalid or expired GitHub token."
            exit 1
        fi
    fi

    # Determine which endpoint to use
    local URL=""
    if [ -n "$GITHUB_TOKEN" ] && { [ -z "$USERNAME" ] || [ "$USERNAME" = "$AUTHENTICATED_USER" ]; }; then
        # Fetch all repos (public and private) of authenticated user
        URL="https://api.github.com/user/repos?per_page=100"
        echo "Fetching repositories for authenticated user '$AUTHENTICATED_USER'..."
    elif [ -n "$USERNAME" ]; then
        # Fetch public repos of specified user
        URL="https://api.github.com/users/$USERNAME/repos?per_page=100"
        echo "Fetching public repositories for user '$USERNAME'..."
    else
        echo "Error: Username required if no token is provided."
        exit 1
    fi

    echo "--------------------------------"

    local auth_header=""
    if [ -n "$GITHUB_TOKEN" ]; then
        auth_header="Authorization: token $GITHUB_TOKEN"
    fi

    # Fetch repos with pagination
    while [ -n "$URL" ]; do
        response=$(curl -s -H "$auth_header" "$URL")
        echo "$response" | jq -r '.[] | .name'

        # Get the 'next' URL from the 'Link' header
        link_header=$(curl -s -I -H "$auth_header" "$URL" | grep -i '^Link: ' | tr -d '\r\n')
        if [[ $link_header =~ \<([^>]+)\>\;[[:space:]]rel=\"next\" ]]; then
            URL="${BASH_REMATCH[1]}"
        else
            URL=""
        fi
    done

    echo "--------------------------------"
    echo "Fetch complete."
}

main "$@"
