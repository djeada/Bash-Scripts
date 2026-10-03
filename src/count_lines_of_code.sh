#!/usr/bin/env bash

# Script Name: count_lines_of_code.sh
# Description: Counts the total number of lines in the files tracked by a git
#              repository (current working tree; binary files are skipped).
# Usage: count_lines_of_code.sh [repository_path]
#       repository_path - the path to a git repository (or a directory inside one);
#                         if no path is specified, the current working directory is used.
# Example: ./count_lines_of_code.sh path/to/repository

get_repository_path() {
    local path=${1:-"."}
    if [ ! -d "$path" ] || ! git -C "$path" rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        echo "Error: '$path' is not a valid Git repository directory." >&2
        exit 1
    fi
    echo "$path"
}

count_lines_of_code() {
    local repository_path="$1"
    local lines
    # git grep -c '' prints "file:count" for every tracked text file (-I skips binaries).
    lines=$(git -C "$repository_path" grep -I -c '' -- . | awk -F: '{ total += $NF } END { print total + 0 }')
    echo "Total lines of code: $lines"
}

main() {
    if [ $# -gt 1 ]; then
        echo "Usage: $0 [repository_path]" >&2
        exit 1
    fi
    if ! command -v git > /dev/null 2>&1; then
        echo "Error: this script requires 'git'." >&2
        exit 1
    fi
    local repository_path
    repository_path="$(get_repository_path "$@")" || exit 1
    count_lines_of_code "$repository_path"
}

main "$@"

