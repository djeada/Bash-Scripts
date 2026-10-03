#!/usr/bin/env bash

# Script Name: remove_n_last_commits.sh
# Description: Removes the last n commits from a git branch (git reset --hard) and,
#              if an 'origin' remote exists, force-pushes the branch to it
#              (--force-with-lease). Refuses to run with uncommitted changes.
# Usage: remove_n_last_commits.sh number_of_commits [branch_name] [directory_path]
#        number_of_commits - the number of commits to remove.
#        branch_name - the name of the branch to remove commits from (optional, defaults to current branch).
#        directory_path - the path to the git repository (optional, defaults to current working directory).
# Example: ./remove_n_last_commits.sh 10 my_branch /path/to/repository

die() {
    echo "Error: $*" >&2
    exit 1
}

validate_arguments() {
    # Validates the arguments provided
    if [ "$#" -lt 1 ] || [ "$#" -gt 3 ]; then
        echo "Usage: remove_n_last_commits.sh number_of_commits [branch_name] [directory_path]" >&2
        echo "       number_of_commits - the number of commits to remove." >&2
        echo "       branch_name - the name of the branch to remove commits from (optional, defaults to current branch)." >&2
        echo "       directory_path - the path to the git repository (optional, defaults to current working directory)." >&2
        exit 1
    fi

    if ! [[ "$1" =~ ^[1-9][0-9]*$ ]]; then
        die "number_of_commits must be a positive integer, got '$1'."
    fi
}

set_working_directory() {
    # Sets the working directory to the specified path
    # Arguments:
    #   $1: The path to the working directory
    local working_dir="$1"
    [ -d "$working_dir" ] || die "The specified directory '$working_dir' does not exist."
    cd "$working_dir" || die "Cannot change to directory '$working_dir'."
}

check_git_repository() {
    # Checks if the current directory is a Git repository
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        die "Not inside a Git repository! Please provide a correct path."
    fi
}

check_branch_exists() {
    # Checks if the specified branch exists in the local repository
    # Arguments:
    #   $1: The name of the branch to check
    local branch_name="$1"
    if ! git show-ref --verify --quiet "refs/heads/$branch_name"; then
        die "The specified branch '$branch_name' does not exist."
    fi
}

remove_n_last_commits() {
    # Removes the last n commits from the specified branch
    # Arguments:
    #   $1: The number of commits to remove
    #   $2: The name of the branch to remove commits from
    local number_of_commits="$1"
    local branch_name="$2"

    # git reset --hard would silently destroy uncommitted work
    if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
        die "The working tree has uncommitted changes. Commit or stash them first."
    fi

    git checkout "$branch_name" || die "Failed to check out '$branch_name'."

    if ! git rev-parse --verify --quiet "HEAD~${number_of_commits}^{commit}" >/dev/null; then
        die "Branch '$branch_name' has fewer than $((number_of_commits + 1)) commits."
    fi

    git reset --hard "HEAD~${number_of_commits}" || die "git reset failed."

    if git remote get-url origin >/dev/null 2>&1; then
        git push --force-with-lease origin "$branch_name" || die "Force push to origin failed."
    else
        echo "No 'origin' remote; skipping push."
    fi
}

main() {
    validate_arguments "$@"

    local number_of_commits="$1"
    local branch_name="${2:-}"

    if [ "$#" -eq 3 ]; then
        set_working_directory "$3"
    fi

    check_git_repository

    if [ -z "$branch_name" ]; then
        branch_name=$(git symbolic-ref --quiet --short HEAD) || die "HEAD is detached; please specify a branch name."
    fi

    check_branch_exists "$branch_name"
    remove_n_last_commits "$number_of_commits" "$branch_name"
}

main "$@"

