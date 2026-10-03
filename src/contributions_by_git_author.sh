#!/usr/bin/env bash

# Script Name: contributions_by_git_author.sh
# Description: This script counts the number of commits by each author in a Git repository
#              (run it from inside the repository). With a username, it counts only the
#              commits whose author name matches it exactly.
#              Actions are logged to /var/log/contributions_by_git_author.log when writable.
# Usage: ./contributions_by_git_author.sh [username]
# Example: ./contributions_by_git_author.sh
# Example: ./contributions_by_git_author.sh "John Doe"

LOG_FILE="/var/log/contributions_by_git_author.log"

log_action() {
    if [ -w "$LOG_FILE" ] || [ -w "$(dirname "$LOG_FILE")" ]; then
        echo "$(date +"%Y-%m-%d %T"): $1" >> "$LOG_FILE"
    fi
}

# Function to process git log
process_git_log() {
    log_action "Processing git log for all authors."
    git log --pretty="%an" |
    sort |
    uniq -c |
    sort -nr |
    awk '{count = $1; sub(/^ *[0-9]+ /, ""); print $0 ": " count " commits"}'
}

# Function to process git log for a specific user
process_git_log_for_user() {
    local count
    log_action "Processing git log for user $1."
    count=$(git log --pretty="%an" | grep -Fxc -- "$1")
    echo "$1: $count commits"
}

main() {
    if [[ $# -gt 1 ]]; then
        echo "Usage: $0 [username]" >&2
        exit 1
    fi

    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo "Error: not inside a git repository." >&2
        exit 1
    fi

    if [[ $# -eq 0 ]]; then
        # No username provided, get commit counts for all authors
        echo "Commit counts per author:"
        process_git_log
    else
        # Username provided, get commit count for that user
        echo "Commit count for user $1:"
        process_git_log_for_user "$1"
    fi
    log_action "Final output displayed."
}

main "$@"

