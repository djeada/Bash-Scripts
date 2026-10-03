#!/usr/bin/env bash

# Script Name: remove_branch.sh
# Description: Removes a branch from a git repository, both locally and remotely (origin).
# Usage: remove_branch.sh branch_name
#        branch_name - the name of the branch to remove.
# Example: ./remove_branch.sh test

remove_remote_branch() {
    # Removes a remote branch
    # $1: branch name
    local branch_name="$1"

    git push -d origin "$branch_name"
}

remove_local_branch() {
    # Removes a local branch
    # $1: branch name
    local branch_name="$1"

    git branch -D "$branch_name"
}

remove_branch() {
    # Removes a branch, both locally and remotely
    # $1: branch name
    local branch_name="$1"
    local is_remote_branch=false
    local is_local_branch=false

    if git show-ref --verify --quiet "refs/remotes/origin/$branch_name"; then
        is_remote_branch=true
    fi

    if git show-ref --verify --quiet "refs/heads/$branch_name"; then
        is_local_branch=true
    fi

    if ! $is_remote_branch && ! $is_local_branch; then
        echo "Provided branch doesn't exist." >&2
        exit 1
    fi

    if $is_remote_branch; then
        remove_remote_branch "$branch_name" || { echo "Failed to remove remote branch '$branch_name'." >&2; exit 1; }
    fi

    if $is_local_branch; then
        remove_local_branch "$branch_name" || { echo "Failed to remove local branch '$branch_name'." >&2; exit 1; }
    fi

    echo "Branch '$branch_name' removed successfully."
}

main() {
    # Main function to orchestrate the script

    if [ $# -ne 1 ]; then
        echo "Usage: remove_branch.sh branch_name" >&2
        exit 1
    fi

    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo "Not inside a git repository." >&2
        exit 1
    fi

    remove_branch "$1"
}

main "$@"

