#!/usr/bin/env bash

# Script Name: remove_branch.sh
# Description: Removes a branch from a git repository, both locally and remotely.
# Usage: remove_branch.sh [<branch_name>]
#        [<branch_name>] - the name of the branch to remove.
# Example: ./remove_branch.sh test

main() {

    if [ $# -eq 0 ]; then
        echo "you have to provide the branch name!"
        exit 1
    elif [ $# -eq 1 ]; then
        branch_name="$1"
    else
        echo "currently not supported!"
        exit 1
    fi

    is_remote_branch=$(git branch -r | grep -Fw "$branch_name" > /dev/null)
    is_local_branch=$(git branch -l | grep -Fw "$branch_name" > /dev/null)

    if [ -n "$is_remote_branch" ] && [ -n "$is_local_branch" ]; then
        echo "provided branch doesn't exists"
        exit 1
    fi

    if [ -z "$is_local_branch" ]; then
        git push -d origin "$branch_name"
    fi

    if [ -z "$is_remote_branch" ]; then
        git branch -D "$branch_name"
    fi

}

main "$@"
