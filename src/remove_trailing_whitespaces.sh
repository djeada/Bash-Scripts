#!/usr/bin/env bash

# Script Name: remove_trailing_whitespaces.sh
# Description: This script removes trailing whitespaces from all text files in the provided path.
#              Binary files and .git directories are skipped. Files are edited in place,
#              so their permissions are preserved.
# Usage: remove_trailing_whitespaces.sh [--check] path
#        --check: Check for trailing whitespaces without actually modifying the files.
#                 Exits with 1 if any file contains trailing whitespaces.
#        path: The file or directory to be processed. If not provided, an error will be raised.
# Example: ./remove_trailing_whitespaces.sh --check path/to/directory

checkonly=0
status=0

# Prints (NUL-separated) every text file under $1 that has a line ending in whitespace.
# -I skips binary files, -r doesn't follow symlinks found while recursing.
find_offending_files() {
    grep -rIlZE --exclude-dir=.git -- '[[:space:]]$' "$1"
}

process_file() {
    local file="$1"
    local lines

    if [[ $checkonly -eq 1 ]]; then
        lines=$(grep -nE '[[:space:]]$' "$file" | cut -d: -f1 | paste -sd, -)
        echo "Trailing whitespaces found in ${file} (line(s): ${lines})"
        status=1
    elif sed -i --follow-symlinks 's/[[:space:]]*$//' "$file"; then
        echo "Removed trailing whitespaces from ${file}"
    else
        echo "Failed to process ${file}" >&2
        status=1
    fi
}

main() {
    if [[ $1 == "--check" ]]; then
        checkonly=1
        shift
    fi

    if [ $# -eq 0 ]; then
        echo "Must provide a path!" >&2
        exit 1
    elif [ $# -gt 1 ]; then
        echo "Only one path is supported!" >&2
        exit 1
    fi

    local path="$1"
    local file

    if [ ! -d "$path" ] && [ ! -f "$path" ]; then
        echo "$path is not a valid path!" >&2
        exit 1
    fi

    while IFS= read -r -d '' file; do
        process_file "$file"
    done < <(find_offending_files "$path")

    if [[ $status -eq 0 ]]; then
        echo "Trailing whitespaces checked successfully."
    fi
    exit "$status"
}

main "$@"

