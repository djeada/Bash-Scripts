#!/bin/bash

echo "GitHub Repository Fetcher"

# Function to check if jq is installed
check_jq_installed() {
    if ! command -v jq &> /dev/null; then
        echo "Error: jq is not installed. Please install jq to run this script."
        exit 1
    fi
}

# Function to fetch repos
fetch_repos() {
    local url=$1
    local token=$2
    local auth_header=""

    if [ -n "$token" ]; then
        auth_header="-H Authorization: token $token"
    fi

    curl -s $auth_header "$url" | jq -r '.[] | .name'
}

# Main function
main() {
    check_jq_installed

    if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
        echo "Usage: $0 <github_username> [github_token]"
        exit 1
    fi

    local USERNAME=$1
    local GITHUB_TOKEN=${2:-}
    local URL="https://api.github.com/users/$USERNAME/repos?per_page=100&page=1"

    echo "Fetching repositories for user '$USERNAME'..."
    echo "--------------------------------"

    while [ -n "$URL" ]; do
        fetch_repos $URL $GITHUB_TOKEN
        URL=$(curl -s -I $GITHUB_TOKEN "$URL" | grep -i "link:" | sed -n 's/.*<\([^>]*\)>; rel="next".*/\1/p')
    done

    echo "--------------------------------"
    echo "Fetch complete."
}

main "$@"
