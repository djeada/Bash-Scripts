#!/usr/bin/env bash

# Script Name: download_all_github_repos.sh
# Description: Downloads all repositories of a GitHub user and creates an archive.
# Usage: download_all_github_repos.sh github_username [github_token]
#        github_username - GitHub username to download repositories from.
#        github_token - Optional GitHub personal access token for private repos.
# Example: ./download_all_github_repos.sh johnsmith [token]

download_repos() {
    local user_name="$1"
    local github_token="${2:-}"
    local temp_dir
    local destination

    temp_dir=$(mktemp -d -t repo_archive_XXXXXX)
    if [ $? -ne 0 ]; then
        echo "Error: Can't create a temp dir!"
        exit 1
    fi

    echo "Using the following temp dir: $temp_dir"
    cd "$temp_dir" || { echo "Cannot change directory! Exiting."; exit 1; }

    local repos_json
    repos_json=$(curl -s -H "Authorization: token $github_token" "https://api.github.com/users/$user_name/repos?per_page=100")
    if [ -z "$repos_json" ]; then
        echo "Error: Couldn't fetch repository list or no repositories found."
        exit 1
    fi

    echo "Cloning repositories..."
    echo "--------------------------------"
    echo "$repos_json" | jq -r '.[] | .clone_url' | while read -r repo; do
        git clone "$repo"
    done

    cd ~ || { echo "Cannot return to home directory! Exiting."; exit 1; }

    destination="${user_name}_repo_archive.tar"
    tar -cvf "$destination" "$temp_dir"
    rm -rf "$temp_dir"

    echo "--------------------------------"
    echo "All repositories of $user_name have been archived in $destination"
}

main() {
    if [[ $# -lt 1 ]] || [[ $# -gt 2 ]]; then
        echo "Usage: download_all_github_repos.sh github_username [github_token]"
        exit 1
    fi

    download_repos "$@"
}

main "$@"
