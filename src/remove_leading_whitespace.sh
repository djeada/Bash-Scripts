#!/usr/bin/env bash

# Script Name: remove_leading_whitespace.sh
# Description: Removes leading whitespace (spaces or tabs) from each line of a file or piped input.
#              With a file argument the file is edited in place; without one, stdin is cleaned to stdout.
# Usage: ./remove_leading_whitespace.sh filename
#        cat file | ./remove_leading_whitespace.sh

set -euo pipefail

if [ "$#" -eq 1 ]; then
    # File mode: clean file in place (sed -i keeps permissions and ownership)
    file="$1"
    if [ ! -f "$file" ]; then
        echo "Error: File '$file' does not exist." >&2
        exit 2
    fi
    if [ ! -w "$file" ]; then
        echo "Error: File '$file' is not writable." >&2
        exit 3
    fi
    if ! sed -i 's/^[[:blank:]]*//' "$file"; then
        echo "Error: Failed to process file." >&2
        exit 4
    fi
elif [ "$#" -eq 0 ]; then
    # Pipe mode: clean stdin, output to stdout
    sed 's/^[[:blank:]]*//'
else
    echo "Usage: $0 [filename]" >&2
    exit 1
fi

