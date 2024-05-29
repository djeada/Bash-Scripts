#!/usr/bin/env bash

# Script Name: contributions_by_git_author.sh
# Description: This script counts the number of commits by each author in a Git repository.
# Usage: ./contributions_by_git_author.sh [username]
# Example: ./contributions_by_git_author.sh
# Example: ./contributions_by_git_author.sh JohnDoe

LOG_FILE="/var/log/contributions_by_git_author.log"
LOG_ENABLED=1

log_action() {
    [ $LOG_ENABLED -eq 1 ] && echo "$(date +"%Y-%m-%d %T"): $1" >> $LOG_FILE
}

# Function to process git log
process_git_log() {
    echo "Processing git log..."
    log_action "Processing git log for all authors."
    git log --pretty="%an" |
    sort |
    uniq -c |
    sort -nr |
    awk '{print $2,$3": "$1" commits"}'
}

# Function to process git log for a specific user
process_git_log_for_user() {
    echo "Processing git log for user $1..."
    log_action "Processing git log for user $1."
    git log --pretty="%an" |
    grep -c "$1" |
    awk -v user="$1" '{print user": "$1" commits"}'
}

main() {
    if [[ $# -eq 0 ]] ; then
        # No username provided, get commit counts for all authors
        echo "Getting commit counts per author..."
        log_action "No user specified. Retrieving commit counts for all authors."
        git_log_output=$(process_git_log)
        echo "Commit counts per author retrieved."
        log_action "Commit counts for all authors retrieved."
    else
        # Username provided, get commit count for that user
        echo "Getting commit count for user $1..."
        log_action "User specified: $1. Retrieving commit count for user."
        git_log_output=$(process_git_log_for_user "$1")
        echo "Commit count for user $1 retrieved."
        log_action "Commit count for user $1 retrieved."
    fi

    # Print the final output
    echo "Final output:"
    echo "$git_log_output"
    log_action "Final output displayed."
}

main "$@"
