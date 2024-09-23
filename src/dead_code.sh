#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Script Name: find_dead_code.sh
# Description:
#   This script searches for function and class definitions in Python files within a specified directory
#   and displays those with occurrences less than a specified threshold.
#   It can exclude certain files or directories and offers a verbose mode for detailed logging.
# Usage:
#   find_dead_code.sh [-n threshold] [-d directory] [-e path1,path2] [-v]
# Example:
#   find_dead_code.sh -n 3 -d /path/to/project -e tests,venv -v

# Default values
THRESHOLD=3
DIRECTORY="."
EXCLUDED_PATHS=()
VERBOSE=false

usage() {
    echo "Usage: $0 [-n threshold] [-d directory] [-e path1,path2] [-v]"
    echo "Options:"
    echo "  -n threshold     Minimum occurrences threshold (default: 3)"
    echo "  -d directory     Directory to search in (default: current directory)"
    echo "  -e paths         Comma-separated list of paths to exclude"
    echo "  -v               Enable verbose mode"
    echo "  -h               Display this help message"
}

while getopts ":n:d:e:vh" opt; do
    case $opt in
        n)
            THRESHOLD="$OPTARG"
            ;;
        d)
            DIRECTORY="$OPTARG"
            ;;
        e)
            IFS=',' read -r -a EXCLUDED_PATHS <<< "$OPTARG"
            ;;
        v)
            VERBOSE=true
            ;;
        h)
            usage
            exit 0
            ;;
        \?)
            echo "Error: Invalid option -$OPTARG"
            usage
            exit 1
            ;;
        :)
            echo "Error: Option -$OPTARG requires an argument"
            usage
            exit 1
            ;;
    esac
done

if [ ! -d "$DIRECTORY" ]; then
    echo "Error: Specified directory does not exist."
    exit 1
fi

# Function to recursively find all Python files in the specified directory, excluding specified paths
find_python_files() {
    local find_cmd=("find" "$DIRECTORY")
    if [ "${#EXCLUDED_PATHS[@]}" -gt 0 ]; then
        find_cmd+=("(")
        local first=true
        for excluded_path in "${EXCLUDED_PATHS[@]}"; do
            if [ "$first" = true ]; then
                first=false
            else
                find_cmd+=("-o")
            fi
            find_cmd+=("-path" "$DIRECTORY/$excluded_path" "-o" "-path" "$DIRECTORY/$excluded_path/*")
        done
        find_cmd+=(")" "-prune" "-o")
    fi
    find_cmd+=("-type" "f" "-name" "*.py" "-print0")
    "${find_cmd[@]}"
}

# Store the list of Python files in an array
mapfile -d '' -t PYTHON_FILES < <(find_python_files)

if [ "${#PYTHON_FILES[@]}" -eq 0 ]; then
    echo "No Python files found in the specified directory."
    exit 0
fi

# Function to extract function and class names
extract_names() {
    local file
    for file in "${PYTHON_FILES[@]}"; do
        if $VERBOSE; then
            echo "Processing file: $file"
        fi
        grep -Eho '^\s*(def|class)\s+[a-zA-Z_][a-zA-Z0-9_]*' "$file" | awk '{print $2}'
    done | sort | uniq
}

# Function to count occurrences and display names under threshold
count_and_display() {
    local name
    while IFS= read -r name; do
        if [[ $name =~ ^test ]]; then
            continue
        fi

        local count
        count=$(grep -h -o -w "$name" "${PYTHON_FILES[@]}" | wc -l)
        if [ "$count" -lt "$THRESHOLD" ]; then
            echo "$name occurred $count times"
        fi
    done
}

# Main execution
extract_names | count_and_display
