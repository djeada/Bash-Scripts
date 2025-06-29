#!/usr/bin/env bash
set -euo pipefail

# Function: prepend_text_to_file
# Description: Prepend provided text to the specified file.
#              If the file does not exist, it will be created.
# Usage: prepend_text_to_file <file> <text>
prepend_text_to_file() {
    # Require at least two arguments: a file and some text.
    if [ "$#" -lt 2 ]; then
        echo "Error: Incorrect number of arguments." >&2
        echo "Usage: prepend_text_to_file <file> <text>" >&2
        return 1
    fi

    local file="$1"
    shift
    # Combine all remaining arguments as the text to prepend.
    local text="$*"

    # If the file exists but is not a regular file, exit with error.
    if [ -e "$file" ] && [ ! -f "$file" ]; then
        echo "Error: '$file' exists but is not a regular file." >&2
        return 1
    fi

    # If the file doesn't exist, create it.
    if [ ! -e "$file" ]; then
        echo "Notice: File '$file' does not exist. Creating file..."
        touch "$file"
    fi

    # Ensure the file is writable.
    if [ ! -w "$file" ]; then
        echo "Error: File '$file' is not writable." >&2
        return 1
    fi

    # Create a secure temporary file.
    local tmpfile
    tmpfile=$(mktemp) || { echo "Error: Could not create temporary file." >&2; return 1; }
    # Ensure the temporary file is removed on function exit.
    trap 'rm -f "$tmpfile"' RETURN

    # Prepend the text: write the new text first, then the existing file content.
    { echo "$text"; cat "$file"; } > "$tmpfile"
    mv "$tmpfile" "$file"
    # Clear the temporary file trap (temporary file has been moved).
    trap - RETURN

    # Log the action.
    echo "The following text was prepended to the file '$file':"
    echo "$text"
}

# Main function to call the prepend_text_to_file function.
main() {
    if [ "$#" -lt 2 ]; then
        echo "Usage: $0 <file> <text>" >&2
        exit 1
    fi
    prepend_text_to_file "$@"
}

main "$@"

