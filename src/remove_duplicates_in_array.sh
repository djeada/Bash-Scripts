#!/usr/bin/env bash

# Script Name: remove_duplicates_in_array.sh
# Description: Script to remove duplicates in an array, keeping the first
#              occurrence of each value in its original order.
# Usage: remove_duplicates_in_array.sh value1 value2 ...
#        value1, value2, ... - Values to remove duplicates from.
# Example: remove_duplicates_in_array.sh a b c d a b c d
# Output: a b c d

remove_duplicates() {
    local -A seen=()
    local unique=()
    local element

    for element in "$@"; do
        # Prefix the key so that an empty string is also a valid key.
        if [[ -z "${seen["_$element"]:-}" ]]; then
            seen["_$element"]=1
            unique+=("$element")
        fi
    done

    echo "${unique[*]}"
}

validate_arguments() {
    # Validates the number of arguments provided
    # Arguments:
    #   $1: The number of arguments provided
    if [ "$1" -eq 0 ]; then
        {
            echo "Usage: remove_duplicates_in_array.sh value1 value2 ..."
            echo "       value1, value2, ... - Values to remove duplicates from."
            echo "Example: remove_duplicates_in_array.sh a b c d a b c d"
        } >&2
        exit 1
    fi
}

main() {
    validate_arguments "$#"
    remove_duplicates "$@"
}

main "$@"

