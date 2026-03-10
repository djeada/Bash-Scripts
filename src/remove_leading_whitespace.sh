#!/bin/bash
# remove_leading_whitespace.sh
# Removes leading whitespace (spaces or tabs) from each line.
# Usage:
#   ./remove_leading_whitespace.sh filename   # Cleans file in place
#   cat file | ./remove_leading_whitespace.sh # Cleans piped input, outputs to stdout

set -euo pipefail

if [ "$#" -eq 1 ]; then
    # File mode: clean file in place
    file="$1"
    if [ ! -f "$file" ]; then
        echo "Error: File '$file' does not exist." >&2
        exit 2
    fi
    if [ ! -w "$file" ]; then
        echo "Error: File '$file' is not writable." >&2
        exit 3
    fi
    tmpfile=$(mktemp --tmpdir "rlw.XXXXXX")
    trap 'rm -f "$tmpfile"' EXIT
    if sed 's/^[ \t]*//' "$file" > "$tmpfile"; then
        mv -- "$tmpfile" "$file"
        trap - EXIT
    else
        echo "Error: Failed to process file." >&2
        exit 4
    fi
elif [ "$#" -eq 0 ]; then
    # Pipe mode: clean stdin, output to stdout
    sed 's/^[ \t]*//'
else
    echo "Usage: $0 [filename]" >&2
    exit 1
fi

