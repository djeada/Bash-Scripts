#!/usr/bin/env bash

# Script Name: switch_slashes.sh
# Description: Script to replace left slashes with right slashes and vice versa
# Usage: switch_slashes.sh [file_name] <direction> [-v]
#       [file_name] - file to be changed
#       <left_to_right | right_to_left | invert> - if not specified, the direction is set to invert
#       [-v] - verbose mode; if set, logs the actions
# Example: ./switch_slashes.sh myfile.txt left_to_right -v

verbose=false

log() {
    if [ "$verbose" = true ]; then
        echo "$1"
    fi
}

main() {
    if [ $# -lt 1 ] || [ $# -gt 3 ]; then
        echo "Usage: switch_slashes.sh [file_name] [<direction>] [-v]"
        echo "       [file_name] - file to be changed"
        echo "       <left_to_right | right_to_left | invert> - if not specified, the direction is set to invert"
        echo "       [-v] - verbose mode; if set, logs the actions"
        echo "Example: ./switch_slashes.sh myfile.txt left_to_right -v"
        exit 1
    fi

    file_name="$1"
    direction="${2:-invert}"

    if [[ "$3" == "-v" ]] || [[ "$2" == "-v" ]]; then
        verbose=true
    fi

    log "Processing file: $file_name"
    log "Direction: $direction"

    case "$direction" in
        left_to_right)
            log "Replacing left slashes with right slashes..."
            sed -i 's|/|\\|g' "$file_name"
            ;;
        right_to_left)
            log "Replacing right slashes with left slashes..."
            sed -i 's|\\|/|g' "$file_name"
            ;;
        invert)
            log "Inverting slashes..."
            sed -i 's|/|TEMP_SLASH|g; s|\\|/|g; s|TEMP_SLASH|\\|g' "$file_name"
            ;;
        *)
            echo "Invalid direction: $direction"
            echo "Valid options are: left_to_right, right_to_left, invert"
            exit 1
            ;;
    esac

    log "Processing complete."
}

main "$@"
