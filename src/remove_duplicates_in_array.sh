#!/usr/bin/env bash

# Script Name: remove_duplicates_in_array.sh
# Description: Script to remove duplicates in an array.
# Usage: remove_duplicates_in_array.sh [list of values]
#       [list of values] - List of values to remove duplicates from.
# Example: remove_duplicates_in_array.sh a b c d a b c d
# Output: a b c d

remove_duplicates() {
    local array=("$@")
    local -A histogram=()

    for element in "${array[@]}"; do
        ((histogram[$element]++))
    done

    for element in "${!histogram[@]}"; do
        if [[ ${histogram[$element]} -gt 1 ]]; then
            echo -n "$element"
        fi
    done

    echo
}

main() {
    if [ $# -eq 0 ]; then
        echo "Usage: remove_duplicates_in_array.sh [list of values]"
        echo "       [list of values] - List of values to remove duplicates from."
        echo "Example: remove_duplicates_in_array.sh a b c d a b c d"
        exit 1
    fi

    remove_duplicates "$@"
}

main "$@"

