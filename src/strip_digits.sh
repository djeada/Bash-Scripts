#!/usr/bin/env bash

# Script Name: strip_digits.sh
# Description: Removes all digits from each string in a given file (in place).
# Usage: strip_digits.sh <file_path>
#        <file_path> - the path to the file to process.
# Example: ./strip_digits.sh path/to/file

main() {
    if [ $# -ne 1 ]; then
        echo "Usage: strip_digits.sh <file_path>" >&2
        exit 1
    fi

    if [ ! -f "$1" ]; then
        echo "$1 is not a valid file path!" >&2
        exit 1
    fi

    # -i edits in place, keeping the file's permissions and ownership.
    sed -i 's/[0-9]//g' "$1"
}

main "$@"

