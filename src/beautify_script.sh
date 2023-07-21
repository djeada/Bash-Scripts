#!/usr/bin/env bash

# Script Name: beautify_script.sh
# Description: This script will format shell scripts using Beautysh and then perform a ShellCheck analysis.
# Usage: beautify_script.sh [--check] path
#        --check - When specified, script will only check if formatting is needed without actually formatting
#        path - The path can be a directory or a single file.
# Example: ./beautify_script.sh ./my_directory

status=0

format() {
    local filepath=$1
    local checkonly=$2
    local origfile
    local fmtfile

    if [[ $filepath == *.sh ]]; then
        echo "Processing $filepath"

        if [[ $checkonly -ne 1 ]]; then
            if ! beautysh "$filepath"; then
                echo "An error occurred while formatting $filepath."
                status=1
            fi

            if ! shellcheck --exclude=SC1091,SC2001 "$filepath"; then
                echo "ShellCheck reported issues in $filepath."
                status=1
            fi
        else
            origfile=$(cat "$filepath")
            fmtfile=$(beautysh - < "$filepath")
            if [[ "$origfile" != "$fmtfile" ]]; then
                echo "$filepath requires formatting"
                status=1
            fi

            if ! shellcheck --exclude=SC1091,SC2001 "$filepath"; then
                echo "ShellCheck reported issues in $filepath."
                status=1
            fi
        fi
    fi
}

# Check for the necessary tools before starting
if ! command -v beautysh > /dev/null; then
    echo "beautysh is not installed. Please install it to format shell scripts."
    exit 1
fi

if ! command -v shellcheck > /dev/null; then
    echo "shellcheck is not installed. Please install it to perform shell script analysis."
    exit 1
fi

main() {
    local checkonly=0

    if [[ $1 == "--check" ]]; then
        checkonly=1
        shift
    fi

    if [ $# -eq 0 ]; then
        echo "Error: No arguments provided."
        echo "Usage: beautify_script.sh [--check] path"
        echo "       --check - When specified, script will only check if formatting is needed without actually formatting"
        echo "       path - The path can be a directory or a single file."
        echo "Example: ./beautify_script.sh ./my_directory"
        exit 1
    fi

    local path="$1"

    if [ -d "$path" ]; then
        while IFS= read -r -d '' file
        do
            format "$file" "$checkonly"
        done < <(find "$path" -name '*.sh' -print0)
    elif [ -f "$path" ]; then
        format "$path" "$checkonly"
    else
        echo "Error: '$path' is not a valid path!"
        exit 1
    fi

    if [[ $status -eq 1 ]]; then
        exit 1
    fi
}

main "$@"

