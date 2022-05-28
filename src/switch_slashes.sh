#!/usr/bin/env bash

# Script Name: switch_slashes.sh
# Description: Script to replace left slashes with right slashes and vice versa
# Usage: switch_slashes.sh [file_name] <direction>
#       [file_name] - file to be changed
#       <left_to_right | right_to_left | invert> - if not specified the direction is set to invert 
# Example: ./switch_slashes.sh left_to_right

main() {
    if [ $# -eq 0 ] || [ $# -gt 2 ]; then
        echo "Usage: switch_slashes.sh [file_name] [<direction>]"
        echo "       [file_name] - file to be changed"
        echo "       <left_to_right | right_to_left | invert> - if not specified the direction is set to invert"
        echo "Example: ./switch_slashes.sh left_to_right"
        exit 1
    fi

    file_name="$1"

    if [[ "$2" == left_to_right ]]; then
        sed -i 's|\/|\\|g' "$file_name"
    elif [[ "$2" == right_to_left ]]; then
        sed -i 's|\\|\/|g' "$file_name"
    elif [[ "$2" == invert ]] || [[ "$#" == 1 ]]; then
        return
    fi

}

main "$@"

