#!/usr/bin/env bash

# Script Name: remove_n_last_commits.sh
# Description: Removes the last n commits from a git repository.
# Usage: remove_n_last_commits.sh number_of_commits [branch_name] [directory_path]
#        number_of_commits - the number of commits to remove.
#        branch_name - the name of the branch to remove commits from (optional, defaults to current branch).
#        directory_path - the path to the git repository (optional, defaults to current working directory).
# Example: ./remove_n_last_commits.sh 10 my_branch /path/to/repository

validate_arguments() {
    # Validates the number of arguments provided
    # Arguments:
    #   $1: The number of arguments provided
    if [ "$1" -lt 1 ] || [ "$1" -gt 3 ]; then
        echo "Usage: remove_n_last_commits.sh number_of_commits [branch_name] [directory_path]"
        echo "       number_of_commits - the number of commits to remove."
        echo "       branch_name - the name of the branch to remove commits from (optional, defaults to current branch)."
        echo "       directory_path - the path to the git repository (optional, defaults to current working directory)."
        exit 1
    fi
}

set_working_directory() {
    # Sets the working directory to the specified path or the current working directory
    # Arguments:
    #   $1: The path to the working directory (optional)
    if [ -n "$1" ]; then
        local working_dir="$1"
        if [ ! -d "$working_dir" ]; then
            echo "The specified directory '$working_dir' does not exist."
            exit 1
        fi
        cd "$working_dir" || exit
    fi
}

check_git_repository() {
    # Checks if the current directory is a Git repository
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "Not inside a Git repository! Please provide a correct path."
        exit 1
    fi
}

check_branch_exists() {
    # Checks if the specified branch exists in the local repository
    # Arguments:
    #   $1: The name of the branch to check
    local branch_name="$1"
    if ! git show-ref --verify --quiet "refs/heads/$branch_name"; then
        echo "The specified branch '$branch_name' does not exist."
        exit 1
    fi
}

remove_n_last_commits() {
    # Removes the last n commits from the specified branch
    # Arguments:
    #   $1: The number of commits to remove
    #   $2: The name of the branch to remove commits from
    local number_of_commits="$1"
    local branch_name="${2:-$(git symbolic-ref --short HEAD)}"

    git checkout "$branch_name"
    git reset --hard HEAD~"$number_of_commits"
    git push -f origin "$branch_name"
}

main() {
    validate_arguments "$#"

    local number_of_commits="$1"
    local branch_name
    local working_dir

    if [ "$#" -ge 2 ]; then
        branch_name="$2"
    fi

    if [ "$#" -eq 3 ]; then
        working_dir="$3"
        set_working_directory "$working_dir"
    fi

    check_git_repository
    check_branch_exists "$branch_name"
    remove_n_last_commits "$number_of_commits" "$branch_name"
}

main "$@"

