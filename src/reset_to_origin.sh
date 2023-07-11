#!/usr/bin/env bash

# Script Name: reset_to_origin.sh
# Description: Resets the local repository to match the remote repository.
# Usage: reset_to_origin.sh branch_name repo_path
#        branch_name - the name of the branch to reset.
#        repo_path - the path to the repository.
# Example: ./reset_to_origin.sh master .

validate_arguments() {
    if [ $# -eq 0 ]; then
        echo "You have to specify the branch name!"
        exit 1
    fi

    if [ $# -eq 1 ] || [ $# -eq 2 ]; then
        local branch_name="$1"
        local is_remote_branch
        local is_local_branch

        is_remote_branch=$(git branch -r | grep -Fw "$branch_name" > /dev/null)
        is_local_branch=$(git branch -l | grep -Fw "$branch_name" > /dev/null)

        if [ "$is_remote_branch" -ne 0 ] && [ "$is_local_branch" -ne 0 ]; then
            echo "The specified branch doesn't exist."
            exit 1
        fi

        if [ $# -eq 2 ]; then
            local working_dir="$2"
            if [ ! -d "$working_dir" ]; then
                echo "$working_dir is not a directory."
                exit 1
            fi
        fi
    else
        echo "You can't specify more than 2 parameters!"
        exit 1
    fi
}

reset_to_origin() {
    local branch_name="$1"
    local working_dir="${2:-.}"

    cd "$working_dir" || exit

    git fetch origin
    git checkout "$branch_name"
    git reset --hard origin/"$branch_name"
    git clean -fdx
}

main() {
    validate_arguments "$@"

    reset_to_origin "$@"
}

main "$@"
