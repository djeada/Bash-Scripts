#!/usr/bin/env bash

# Script Name: reset_local_repo_to_origin.sh
# Description: Script to reset local git repositories to origin.
# Usage: reset_local_repo_to_origin.sh [branch_name] [<path_to_repo>]
#       [branch_name] - Branch name to reset to origin.
#       [<path_to_repo>] - Path to the local git repository.
# Example: reset_local_repo_to_origin.sh master

main() {

    working_dir="."

    if [ $# -eq 0 ]; then
        echo "You have to specify the branch name!"
        exit 1
    fi

    if [ $# -eq 1 ] || [ $# -eq 2 ]; then
        branch_name="$1"
        is_remote_branch=$(git branch -r | grep -Fw $branch_name > /dev/null)
        is_local_branch=$(git branch -l | grep -Fw $branch_name > /dev/null)

        if [ $is_remote_branch -ne 0 ] && [ $is_local_branch -ne 0 ]; then
            echo "provided branch doesn't exists"
            exit 1
        fi

        if  [ $# -eq 2 ]; then
            working_dir="$2"
            if [ ! -d "$working_dir" ]; then
                echo "$workind_dir is not a directory."
                exit 1
            fi
        fi

    else
        echo "You can't specify more than 2 parameters!"
        exit 1
    fi

    cd "$working_dir"

    git fetch origin
    git checkout "$branch_name"
    git reset --hard origin/"$branch_name"
    git clean -fdx

}

main "$@"
