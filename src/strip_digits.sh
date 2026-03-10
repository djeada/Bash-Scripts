#!/usr/bin/env bash

# Script Name: strip_digits.sh
# Description: Removes all digits from each string in a given file.
# Usage: strip_digits.sh [file_path]
#        [file_path] - the path to the file to process.
# Example: ./strip_digits.sh path/to/file

main() {
    if [ $# -eq 0 ]; then
        echo "You must provide a file path!"
        exit 1
    fi

    if [ ! -f "$1" ]; then
        echo "$1 is not a valid file path!"
        exit 1
    fi

    local file_path
    local temp_file

    file_path=$1
    # file_name is not used in the script so I've removed it.

    temp_file=$(mktemp)

    sed -r 's/[^[:space:]]*[0-9][^[:space:]]* ?//g' "$file_path" > "$temp_file"
    mv "$temp_file" "$file_path"

}

main "$@"

