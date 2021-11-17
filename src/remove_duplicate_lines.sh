#!/usr/bin/env bash

# Script Name: remove_duplicate_lines.sh
# Description: Removes duplicate lines from a given file.
# Usage: remove_duplicate_lines.sh [<file_path>]
#        [<file_path>] - the path to the file to process.
# Example: ./remove_duplicate_lines.sh path/to/file

main() {
    if [ $# -eq 0 ]; then
        echo "You must provide a file path!"
        exit 1
    fi

    if [ ! -f $1 ]; then
        echo "$1 is not a valid file path!"
        exit 1
    fi

    local file_path=$1
    local file_name=$(basename $file_path)

    awk '/^\s*$/||!seen[$0]++' $file_path > $file_name.tmp
    mv $file_name.tmp $file_name
}

main "$@"
