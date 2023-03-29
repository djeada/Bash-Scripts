#!/usr/bin/env bash

# Script Name: replace_everywhere.sh
# Description: Replace string a with string b in all files in the current directory and all subdirectories.
# Usage: replace_everywhere.sh [string_a] [string_b]
#       [string_a] - Old string.
#       [string_b] - New string.
# Example: replace_everywhere.sh "cat" "act"
#
# For strings with spaces use single quotes: replace_everywhere.sh 'string with space' ''
# Escape special characters with single slash: replace_everywhere.sh 'string\*\*' ''

main() {
    if [ $# -ne 2 ]; then
        echo "Usage: replace_everywhere.sh [string_a] [string_b]"
        return
    fi

    find . -type f -exec awk -v search="$1" -v replace="$2" 'BEGIN{ORS="";RS=ORS?ORS:search}{print $0 (RT?replace:RT)}' {} > tmp_awk && mv tmp_awk {} \;
}

main "$@"
