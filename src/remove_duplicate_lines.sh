#!/usr/bin/env bash

# Script Name: remove_duplicate_lines.sh
# Description: Removes duplicate lines from a given file in place, keeping the first
#              occurrence of each line. Blank (empty or whitespace-only) lines are kept.
# Usage: remove_duplicate_lines.sh <file_path>
#        <file_path> - the path to the file to process.
# Example: ./remove_duplicate_lines.sh path/to/file

main() {
    if [ $# -eq 0 ]; then
        echo "You must provide a file path!" >&2
        exit 1
    fi

    if [ ! -f "$1" ]; then
        echo "$1 is not a valid file path!" >&2
        exit 1
    fi

    local file_path=$1
    # Global (not local) so the EXIT trap can still see it after main returns
    temp_file=$(mktemp) || exit 1
    trap 'rm -f "$temp_file"' EXIT

    awk '/^[[:space:]]*$/ || !seen[$0]++' "$file_path" > "$temp_file" || exit 1

    # Write back through the existing file to keep its permissions and ownership
    cat "$temp_file" > "$file_path" || exit 1
}

main "$@"

