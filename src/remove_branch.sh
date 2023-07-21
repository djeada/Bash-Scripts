#!/usr/bin/env bash

# Script Name: remove_branch.sh
# Description: Removes a branch from a git repository, both locally and remotely.
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

    is_remote_branch=$(git branch -r | grep -Fw "$branch_name" > /dev/null)
    is_local_branch=$(git branch -l | grep -Fw "$branch_name" > /dev/null)

    if [ -z "$is_remote_branch" ] && [ -z "$is_local_branch" ]; then
        echo "Provided branch doesn't exist."
        exit 1
    fi

    if [ -n "$is_remote_branch" ]; then
        remove_remote_branch "$branch_name"
    fi

    if [ -n "$is_local_branch" ]; then
        remove_local_branch "$branch_name"
    fi

    echo "Branch '$branch_name' removed successfully."
}

main() {
    # Main function to orchestrate the script

    if [ $# -eq 0 ]; then
        echo "You have to provide the branch name!"
        exit 1
    elif [ $# -eq 1 ]; then
        branch_name="$1"
        remove_branch "$branch_name"
    else
        echo "Currently not supported!"
        exit 1
    fi
}

main "$@"

