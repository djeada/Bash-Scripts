#!/usr/bin/env bash

# Script Name: remove_consecutive_blank_lines.sh
# Description: Collapses runs of consecutive blank (empty or whitespace-only) lines
#              into a single blank line in every text file under a directory.
#              Binary files and .git directories are skipped; file permissions are kept.
# Usage: remove_consecutive_blank_lines.sh directory
#        directory - the path to the directory containing the files to process.
# Example: ./remove_consecutive_blank_lines.sh /path/to/directory

validate_arguments() {
    # Validates the number of arguments provided
    # $1: directory
    if [ "$#" -ne 1 ]; then
        echo "Usage: $0 directory" >&2
        exit 1
    fi
}

validate_directory() {
    # Validates if the provided path is a directory
    # $1: directory
    local dir="$1"
    if [ ! -d "$dir" ]; then
        echo "Error: '$dir' is not a directory." >&2
        exit 1
    fi
}

remove_repeated_blank_lines() {
    # Removes repeated blank lines from files in the directory
    # $1: directory
    local dir="$1"
    local file tmp

    tmp=$(mktemp) || exit 1
    trap 'rm -f "$tmp"' EXIT

    while IFS= read -r -d '' file; do
        # Skip binary and empty files
        grep -Iq . "$file" || continue

        awk 'NF == 0 { if (blank) next; blank = 1; print; next } { blank = 0; print }' "$file" > "$tmp" || {
            echo "Error: failed to process '$file'." >&2
            continue
        }

        # Write back in place (keeps permissions/ownership) only when something changed
        if ! cmp -s "$tmp" "$file"; then
            cat "$tmp" > "$file"
        fi
    done < <(find "$dir" -name .git -prune -o -type f -print0)
}

main() {
    # Main function to orchestrate the script
    validate_arguments "$@"
    local dir="$1"
    validate_directory "$dir"
    remove_repeated_blank_lines "$dir"
    echo "Done. Repeated blank lines have been removed from files in the directory."
}

main "$@"

