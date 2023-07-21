#!/usr/bin/env bash

# Script Name: download_all_github_repos.sh
# Description: Downloads all repositories of a GitHub user and creates an archive.
# Usage: download_all_github_repos.sh github_username
#        github_username - GitHub username to download repositories from.
# Example: ./download_all_github_repos.sh johnsmith

download_repos() {
    # Downloads all repositories of the given GitHub user and creates an archive.
    # $1: GitHub username

    local user_name="$1"
    local temp_dir
    local destination

    temp_dir=$(mktemp -d -q /tmp/repo_archive_XXXXXX)

    if ! temp_dir; then
        echo "Error: Can't create a temp dir!"
        exit 1
    fi

    echo "Using the following temp dir: $temp_dir"

    cd "$temp_dir" || exit

    if ! virtualenv env; then
        echo "Error: Couldn't create virtual environment"
        exit 1
    fi

    # shellcheck disable=SC1091
    if ! source env/bin/activate; then
        echo 'Could not source activate'
        exit 1
    fi

    if ! pip install ghcloneall; then
        echo "Error: Couldn't install ghcloneall"
        exit 1
    fi

    if ! ghcloneall --init --user "$user_name"; then
        echo "Error: Couldn't clone all repositories"
        exit 1
    fi

    if ! ghcloneall; then
        echo "Error: Couldn't clone all repositories"
        exit 1
    fi

    deactivate &&
    cd ~ || exit

    destination="${user_name}_repo_archive.tar"

    tar -cvf "$destination" "$temp_dir"

    rm -rf "$temp_dir"

    echo "All repositories of $user_name have been written to $destination"
}

main() {
    # Main function to execute the script

    if [[ $# -ne 1 ]]; then
        echo "Usage: download_all_github_repos.sh github_username"
        exit 1
    fi

    download_repos "$1"
}

main "$@"

