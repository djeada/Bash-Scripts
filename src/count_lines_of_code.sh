#!/usr/bin/env bash

# Script Name: count_lines_of_code.sh
# Description: Counts the total number of lines of code in a given git repository.
# Usage: count_lines_of_code.sh repository_path
#       repository_path - the path to a git repository;
#                           if no path is specified, the current working directory is used.
# Example: ./count_lines_of_code.sh path/to/repository

get_repository_path() {
    local path=${1:-"."}
    if [ ! -d "$path" ] || [ ! -d "$path/.git" ]; then
        echo "Error: '$path' is not a valid Git repository directory."
        exit 1
    fi
    echo "$path"
}

count_lines_of_code() {
    local repository_path="$1"
    local lines
    lines=$(git -C "$repository_path" ls-files | xargs wc -l | awk '/total/{print $1}')
    echo "Total lines of code: $lines"
}

main() {
    local repository_path
    repository_path="$(get_repository_path "$@")"
    count_lines_of_code "$repository_path"
}

main "$@"
