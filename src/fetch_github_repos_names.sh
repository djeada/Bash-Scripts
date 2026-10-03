#!/usr/bin/env bash

# Script Name: fetch_github_repos_names.sh
# Description: Fetches and lists all repositories of a GitHub user.
#              Lists both public and private repositories if a personal access token is provided.
# Usage: ./fetch_github_repos_names.sh [github_username] [github_token]
# Example: ./fetch_github_repos_names.sh johnsmith YOUR_GITHUB_TOKEN

set -euo pipefail

# Display usage message and exit
usage() {
    echo "Usage: $0 [github_username] [github_token]" >&2
    echo "  github_username - Optional. GitHub username to fetch repositories for." >&2
    echo "  github_token    - Optional. Personal access token to access private repositories." >&2
    exit 1
}

# Check that the required tools are installed
check_dependencies() {
    local cmd
    for cmd in curl jq; do
        if ! command -v "$cmd" &>/dev/null; then
            echo "Error: $cmd is not installed. Please install $cmd to run this script." >&2
            exit 1
        fi
    done
}

# Extra curl arguments (the authorization header when a token is given; set in main)
curl_auth_args=()

# Get authenticated user's login using provided token
get_authenticated_user() {
    curl -s "${curl_auth_args[@]}" https://api.github.com/user | jq -r '.login // empty' 2>/dev/null || true
}

# Fetch one page of results.
# Sets the globals 'page_body' (the JSON body) and 'next_url' (next page URL, or empty).
# Globals are used because a command substitution would run in a subshell and lose next_url.
page_body=""
next_url=""
header_file=""
fetch_page() {
    local url="$1"
    local header

    page_body=$(curl -s -D "$header_file" "${curl_auth_args[@]}" "$url") || {
        echo "Error: request to $url failed." >&2
        exit 1
    }
    # HTTP header lines end with CRLF; strip the CR before matching
    header=$(tr -d '\r' < "$header_file")

    # Extract next page URL from the Link header, if available
    if [[ "$header" =~ \<([^>]+)\>\;\ *rel=\"next\" ]]; then
        next_url="${BASH_REMATCH[1]}"
    else
        next_url=""
    fi
}

# Main function
main() {
    if [ "$#" -gt 2 ]; then
        usage
    fi

    echo "GitHub Repository Fetcher"
    check_dependencies

    local USERNAME="${1:-}"
    local GITHUB_TOKEN="${2:-}"
    local AUTHENTICATED_USER=""

    if [ -n "$GITHUB_TOKEN" ]; then
        curl_auth_args=(-H "Authorization: token $GITHUB_TOKEN")
        AUTHENTICATED_USER=$(get_authenticated_user)
        if [ -z "$AUTHENTICATED_USER" ]; then
            echo "Error: Invalid or expired GitHub token." >&2
            exit 1
        fi
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
        echo "Error: Username required if no token is provided." >&2
        usage
    fi

    header_file=$(mktemp)
    trap 'rm -f "$header_file"' EXIT

    echo "--------------------------------"

    # Fetch repositories with pagination
    while [ -n "$URL" ]; do
        fetch_page "$URL"
        # The API returns an object with a "message" on errors (unknown user, rate limit...)
        if ! jq -e 'type == "array"' <<< "$page_body" >/dev/null 2>&1; then
            echo "Error: GitHub API: $(jq -r '.message // "unexpected response"' <<< "$page_body" 2>/dev/null || echo "unexpected response")" >&2
            exit 1
        fi
        jq -r '.[] | .name' <<< "$page_body"
        URL="$next_url"
    done

    echo "--------------------------------"
    echo "Fetch complete."
}

main "$@"

