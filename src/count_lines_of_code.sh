#!/usr/bin/env bash

# Script Name: count_files.sh
# Description: Counts the total number of lines of code in a given git repository.
# Usage: count_files.sh <repository_path>
#       <repository_path> - the path to a git repository; 
#                           if no path is specified, the current working directory is used.
# Example: ./count_files.sh path/to/repository

main() {

    if [ $# -eq 0 ]; then
        path="."
    elif [ -d "$1" ]; then
        path="$1"
    else
        echo "provided path is not valid!"
        exit 1
    fi

    cd "$path" || return
    git ls-files -z | xargs -0 wc -l | awk 'END{print}'
}

main "$@"

