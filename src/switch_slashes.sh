#!/usr/bin/env bash

# Script Name: switch_slashes.sh
# Description: Script to replace forward slashes (/) with backslashes (\) and vice versa in a file (in place).
# Usage: switch_slashes.sh <file_name> [<direction>] [-v]
#       <file_name> - file to be changed
#       [left_to_right | right_to_left | invert] - left_to_right turns / into \, right_to_left turns \ into /,
#                                                  invert swaps both; if not specified, the direction is set to invert
#       [-v] - verbose mode; if set, logs the actions
# Example: ./switch_slashes.sh myfile.txt left_to_right -v

verbose=false

log() {
    if [ "$verbose" = true ]; then
        echo "$1"
    fi
}

usage() {
    echo "Usage: switch_slashes.sh <file_name> [<direction>] [-v]"
    echo "       <file_name> - file to be changed"
    echo "       [left_to_right | right_to_left | invert] - if not specified, the direction is set to invert"
    echo "       [-v] - verbose mode; if set, logs the actions"
    echo "Example: ./switch_slashes.sh myfile.txt left_to_right -v"
}

main() {
    if [ $# -lt 1 ] || [ $# -gt 3 ]; then
        usage >&2
        exit 1
    fi

    local file_name="$1"
    local direction="invert"
    shift

    local arg
    for arg in "$@"; do
        if [ "$arg" = "-v" ]; then
            verbose=true
        else
            direction="$arg"
        fi
    done

    if [ ! -f "$file_name" ]; then
        echo "Error: '$file_name' is not a file." >&2
        exit 1
    fi

    log "Processing file: $file_name"
    log "Direction: $direction"

    case "$direction" in
        left_to_right)
            log "Replacing forward slashes with backslashes..."
            sed -i 's|/|\\|g' "$file_name"
            ;;
        right_to_left)
            log "Replacing backslashes with forward slashes..."
            sed -i 's|\\|/|g' "$file_name"
            ;;
        invert)
            log "Inverting slashes..."
            sed -i 'y|/\\|\\/|' "$file_name"
            ;;
        *)
            echo "Invalid direction: $direction" >&2
            echo "Valid options are: left_to_right, right_to_left, invert" >&2
            exit 1
            ;;
    esac

    log "Processing complete."
}

main "$@"

