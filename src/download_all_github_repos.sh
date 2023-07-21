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

    if ! [ $? -eq 0 ]; then
        echo "Error: Can't create a temp dir!"
        exit 1
    fi

    echo "Using the following temp dir: $temp_dir"

    cd "$temp_dir" || exit
    virtualenv env &&
    source env/bin/activate || { echo 'Could not source activate' ; exit 1; }
    pip install ghcloneall &&
    ghcloneall --init --user "$user_name" &&
    ghcloneall &&
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


