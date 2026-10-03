#!/usr/bin/env bash

# Script Name: squash_n_last_commits.sh
# Description: Squashes the last n commits in a git repository into a single commit
#              (opens the editor, pre-filled with the squashed commits' messages).
# Usage: squash_n_last_commits.sh number_of_commits [branch_name [directory_path]]
#        number_of_commits - the number of commits to squash (at least 2).
#        branch_name - the name of the branch to squash (default: current branch).
#        directory_path - the path to the working directory (default: current directory).
# Example: ./squash_n_last_commits.sh 10 master .

validate_arguments() {
    if [ $# -eq 0 ]; then
        echo "You have to provide the number of commits to squash." >&2
        echo "Optionally, you can provide the branch name and the working directory." >&2
        exit 1
    fi

    if [ $# -gt 3 ]; then
        echo "You can't specify more than 3 parameters!" >&2
        exit 1
    fi

    if ! [[ "$1" =~ ^[0-9]+$ ]] || [ "$((10#$1))" -lt 2 ]; then
        echo "The number of commits must be an integer of at least 2." >&2
        exit 1
    fi
}

set_working_directory() {
    if [ $# -eq 3 ]; then
        local working_dir="$3"
        if [ ! -d "$working_dir" ]; then
            echo "$working_dir is not a directory." >&2
            exit 1
        fi
        cd "$working_dir" || exit 1
    fi
}

check_git_repository() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo "Not inside a git repo! Please provide a correct path." >&2
        exit 1
    fi
}

check_branch() {
    if [ $# -ge 2 ] && ! git show-ref --verify --quiet "refs/heads/$2"; then
        echo "Provided branch doesn't exist." >&2
        exit 1
    fi
}

squash_commits() {
    local n=$((10#$1))
    local branch_name="${2:-}"
    local original_head

    if [ -n "$branch_name" ]; then
        git checkout "$branch_name" || exit 1
    fi

    if ! git diff --cached --quiet; then
        echo "There are staged changes; commit or unstage them first so they aren't squashed in." >&2
        exit 1
    fi

    if ! git rev-parse --verify --quiet "HEAD~$n" > /dev/null; then
        echo "The branch has fewer than $((n + 1)) commits; cannot squash the last $n." >&2
        exit 1
    fi

    original_head=$(git rev-parse HEAD)
    git reset --soft "HEAD~$n" || exit 1
    # Pre-fill the editor with the squashed commits' messages (oldest first).
    if ! git commit --edit -m "$(git log --format=%B --reverse "HEAD..$original_head")"; then
        echo "Commit aborted; restoring the original history." >&2
        git reset --soft "$original_head"
        exit 1
    fi
}

main() {
    validate_arguments "$@"

    set_working_directory "$@"

    check_git_repository

    check_branch "$@"

    squash_commits "$@"
}

main "$@"

