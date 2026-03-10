#!/usr/bin/env bash

# Script Name: remove_duplicates_in_array.sh
# Description: Script to remove duplicates in an array.
# Usage: remove_duplicates_in_array.sh value1 value2 ...
#        value1, value2, ... - Values to remove duplicates from.
# Example: remove_duplicates_in_array.sh a b c d a b c d
# Output: a b c d

remove_duplicates() {
    local array=("$@")
    local -A histogram=()

    for element in "${array[@]}"; do
        ((histogram[$element]++))
    done

    for element in $(printf '%s\n' "${!histogram[@]}" | sort); do
        echo -n "$element "
    done

    echo
}

validate_arguments() {
    # Validates the number of arguments provided
    # Arguments:
    #   $1: The number of arguments provided
    if [ "$1" -eq 0 ]; then
        echo "Usage: remove_duplicates_in_array.sh value1 value2 ..."
        echo "       value1, value2, ... - Values to remove duplicates from."
        echo "Example: remove_duplicates_in_array.sh a b c d a b c d"
        exit 1
    fi
}

main() {
    validate_arguments "$#"
    remove_duplicates "$@"
}

main "$@"

