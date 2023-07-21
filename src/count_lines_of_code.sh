#!/usr/bin/env bash

# Script Name: count_lines_of_code.sh
# Description: Counts the total number of lines of code in a given git repository.
# Usage: count_lines_of_code.sh repository_path
#       repository_path - the path to a git repository;
#                           if no path is specified, the current working directory is used.
# Example: ./count_lines_of_code.sh path/to/repository

get_repository_path() {
    if [ $# -eq 0 ]; then
        echo "."
    else
        local path="$1"
        if [ -d "$path" ]; then
            echo "$path"
        else
            echo "Provided path is not valid!"
            exit 1
        fi
    fi
}

count_lines_of_code() {
    local repository_path="$1"
    cd "$repository_path" || return
    git ls-files -z | xargs -0 wc -l | awk 'END{print}'
}

main() {
    local repository_path=""
    repository_path="$(get_repository_path "$@")"
    count_lines_of_code "$repository_path"
}

main "$@"

