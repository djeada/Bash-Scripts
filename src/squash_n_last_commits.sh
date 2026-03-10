#!/usr/bin/env bash

# Script Name: squash_n_last_commits.sh
# Description: Squashes the last n commits in a git repository.
# Usage: squash_n_last_commits.sh number_of_commits branch_name directory_path
#        number_of_commits - the number of commits to squash.
#        branch_name - the name of the branch to squash.
#        directory_path - the path to the working directory.
# Example: ./squash_n_last_commits.sh 10 master .

validate_arguments() {
    if [ $# -eq 0 ]; then
        echo "You have to provide the number of commits to squash."
        echo "Optionally, you can provide the branch name and the working directory."
        exit 1
    fi

    if [ $# -gt 3 ]; then
        echo "You can't specify more than 3 parameters!"
        exit 1
    fi
}

set_working_directory() {
    if [ $# -eq 3 ]; then
        local working_dir="$3"
        if [ ! -d "$working_dir" ]; then
            echo "$working_dir is not a directory."
            exit 1
        fi
        cd "$working_dir" || exit
    fi
}

check_git_repository() {
    local is_git_repo=0
    is_git_repo=$(git rev-parse --git-dir > /dev/null 2>&1)

    if [ ${#is_git_repo} -gt 0 ]; then
        echo "Not inside a git repo! Please provide a correct path."
        exit 1
    fi
}

check_branch() {
    if [ $# -eq 3 ]; then
        local branch_name="$2"
        local is_local_branch=0
        is_local_branch=$(git branch -l | grep -Fw "$branch_name")

        if [ ${#is_local_branch} -eq 0 ]; then
            echo "Provided branch doesn't exist."
            exit 1
        fi
    fi
}

squash_commits() {
    local n="$1"
    local branch_name="$2"

    git checkout "$branch_name"
    git reset --soft HEAD~"$n"
    git commit
}

main() {
    validate_arguments "$@"

    set_working_directory "$@"

    check_git_repository

    check_branch "$@"

    squash_commits "$@"
}

main "$@"

