#!/usr/bin/env bash

# Script Name: remove_empty_lines.sh
# Description: Removes all lines that are empty or contain only whitespace from a given file (in place).
# Usage: remove_empty_lines.sh <file_path>
#        <file_path> - the path to the file to process.
# Example: ./remove_empty_lines.sh path/to/file

main() {
    if [ $# -ne 1 ]; then
        echo "Usage: remove_empty_lines.sh <file_path>" >&2
        exit 1
    fi

    if [ ! -f "$1" ]; then
        echo "$1 is not a valid file path!" >&2
        exit 1
    fi

    # -i edits in place, keeping the file's permissions and ownership.
    sed -i '/^[[:space:]]*$/d' "$1"
}

main "$@"

