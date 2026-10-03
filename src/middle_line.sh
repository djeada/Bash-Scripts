#!/usr/bin/env bash

# Script Name: middle_line.sh
# Description: Prints the middle line of a file (for an even number of lines,
#              the first of the two middle lines).
# Usage: middle_line.sh file_name
#        file_name - the name of the file to print the middle line of.
# Example: ./middle_line.sh path/to/file.txt

main() {
    if [ $# -eq 0 ]; then
        echo "You must provide a file path!" >&2
        exit 1
    fi

    file_path=$1

    if [ ! -f "$file_path" ]; then
        echo "$file_path is not a valid file path!" >&2
        exit 1
    fi

    if [ ! -r "$file_path" ]; then
        echo "Cannot read $file_path!" >&2
        exit 1
    fi

    if [ ! -s "$file_path" ]; then
        echo "$file_path is empty!" >&2
        exit 1
    fi

    # awk also counts a last line that has no trailing newline (wc -l does not).
    total_lines=$(awk 'END { print NR }' "$file_path")
    middle_line=$(((total_lines + 1) / 2))

    sed -n "${middle_line}{p;q}" "$file_path"
}

main "$@"

