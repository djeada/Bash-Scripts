#!/usr/bin/env bash

# Script Name: reset_to_origin.sh
# Description: Resets the local repository to match the remote repository.
#              WARNING: discards all local changes and commits on the branch and
#              runs `git clean -fdx`, which also deletes untracked AND ignored
#              files (build output, .env files, node_modules, ...).
# Usage: reset_to_origin.sh branch_name [repo_path]
#        branch_name - the name of the branch to reset.
#        repo_path - the path to the repository (default: current directory).
# Example: ./reset_to_origin.sh master .

validate_arguments() {
    if [ $# -eq 0 ]; then
        echo "You have to specify the branch name!" >&2
        exit 1
    fi

    if [ $# -gt 2 ]; then
        echo "You can't specify more than 2 parameters!" >&2
        exit 1
    fi

    if [ $# -eq 2 ] && [ ! -d "$2" ]; then
        echo "$2 is not a directory." >&2
        exit 1
    fi
}

reset_to_origin() {
    local branch_name="$1"
    local working_dir="${2:-.}"

    cd "$working_dir" || exit 1

    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo "$working_dir is not a git repository." >&2
        exit 1
    fi

    git fetch origin || exit 1

    if ! git show-ref --verify --quiet "refs/remotes/origin/$branch_name"; then
        echo "The branch '$branch_name' doesn't exist on origin." >&2
        exit 1
    fi

    git checkout "$branch_name" || exit 1
    git reset --hard "origin/$branch_name" || exit 1
    git clean -fdx
}

main() {
    validate_arguments "$@"

    reset_to_origin "$@"
}

main "$@"

