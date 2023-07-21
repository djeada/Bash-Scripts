#!/usr/bin/env bash

# Script Name: contributions_by_git_author.sh
# Description: This script counts the number of commits by each author in a Git repository.
# Usage: ./contributions_by_git_author.sh [username]
# Example: ./contributions_by_git_author.sh
# Example: ./contributions_by_git_author.sh JohnDoe

# Function to process git log
process_git_log() {
    echo "Processing git log..."
    git log --pretty="%an" |
    sort |
    uniq -c |
    sort -nr |
    awk '{print $2,$3": "$1" commits"}'
}

# Function to process git log for a specific user
process_git_log_for_user() {
    echo "Processing git log for user $1..."
    git log --pretty="%an" |
    grep -c "$1" |
    awk -v user="$1" '{print user": "$1" commits"}'
}

main() {
    if [[ $# -eq 0 ]] ; then
        # No username provided, get commit counts for all authors
        echo "Getting commit counts per author..."
        git_log_output=$(process_git_log)
        echo "Commit counts per author retrieved."
    else
        # Username provided, get commit count for that user
        echo "Getting commit count for user $1..."
        git_log_output=$(process_git_log_for_user "$1")
        echo "Commit count for user $1 retrieved."
    fi

    # Print the final output
    echo "Final output:"
    echo "$git_log_output"
}

main "$@"

