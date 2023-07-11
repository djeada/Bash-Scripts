#!/usr/bin/env bash

# Script Name: beautify_script.sh
# Description: This script will format shell scripts using Beautysh and then perform a ShellCheck analysis.
# Usage: code_formatter.sh path
#        path - The path can be a directory or a single file. For a directory, the script will recursively format and check all shell script files within it.
# Example: ./beautify_script.sh ./my_directory

# Function: Apply formatting using Beautysh and then perform a ShellCheck analysis
format() {
    local filepath=$1

    if [[ $filepath == *.sh ]]; then
        echo "Formatting and performing shellcheck on $filepath"

        # Ensure that beautysh and shellcheck are installed
        if command -v beautysh > /dev/null; then
            beautysh "$filepath"
        else
            echo "beautysh is not installed. Please install it to format shell scripts."
        fi

        if command -v shellcheck > /dev/null; then
            shellcheck "$filepath"
        else
            echo "shellcheck is not installed. Please install it to perform shell script analysis."
        fi
    fi
}

# Function: Main function to control the flow of the script
main() {
    # Ensure that a path is provided
    if [ $# -eq 0 ]; then
        echo "Error: No arguments provided."
        echo "Usage: code_formatter.sh path"
        echo "       path - The path can be a directory or a single file."
        echo "Example: ./beautify_script.sh ./my_directory"
        exit 1
    fi

    local path="$1"

    # Check if the path is a directory
    if [ -d "$path" ]; then
        # Format all .sh files in the directory and subdirectories
        while IFS= read -r -d '' file
        do
            format "$file"
        done < <(find "$path" -name '*.sh' -print0)
        # Check if the path is a file
    elif [ -f "$path" ]; then
        format "$path"
    else
        echo "Error: '$path' is not a valid path!"
        exit 1
    fi
}

main "$@"
