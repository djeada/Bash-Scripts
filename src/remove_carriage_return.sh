#!/usr/bin/env bash

# Script Name: remove_carriage_return.sh
# Description: Checks and removes the carriage return from all the text files in a given path.
#              Binary files and .git directories are skipped. Files are edited in place,
#              so their permissions are preserved.
# Usage: remove_carriage_return.sh [--check] path
#        --check - When specified, script will only check if the files contain carriage returns without actually removing them.
#                  Exits with 1 if any file contains a carriage return.
#        path - the file or directory to process.
# Example: ./remove_carriage_return.sh --check path/to/directory

checkonly=0
status=0

remove_carriage_return() {
    # Removes carriage return from a file
    # $1: file path
    local file="$1"

    if [[ $checkonly -eq 1 ]]; then
        echo "File $file contains carriage return"
        status=1
    elif sed -i --follow-symlinks 's/\r//g' "$file"; then
        echo "Removed carriage return from $file"
    else
        echo "Failed to process $file" >&2
        status=1
    fi
}

main() {
    # Main function to orchestrate the script

    if [[ $1 == "--check" ]]; then
        checkonly=1
        shift
    fi

    if [ $# -ne 1 ]; then
        echo "Must provide exactly one path!" >&2
        exit 1
    fi

    local path="$1"
    local file

    if [ ! -d "$path" ] && [ ! -f "$path" ]; then
        echo "$path is not a valid path!" >&2
        exit 1
    fi

    # grep lists (NUL-separated) only the text files that contain a carriage return;
    # -I skips binary files, -r doesn't follow symlinks found while recursing.
    while IFS= read -r -d '' file; do
        remove_carriage_return "$file"
    done < <(grep -rlIZ --exclude-dir=.git -- $'\r' "$path")

    if [[ $status -ne 0 ]]; then
        if [[ $checkonly -eq 1 ]]; then
            echo "One or more files contain carriage return."
        fi
        exit 1
    fi

    echo "Carriage return checked successfully."
    exit 0
}

main "$@"

