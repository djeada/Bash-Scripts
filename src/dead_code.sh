#!/usr/bin/env bash

# Script Name: find_dead_code.sh
# Description: This script searches for function and class definitions in Python files within a specified directory and displays those with occurrences less than a specified threshold. It can also exclude certain files or directories and offers a verbose mode for detailed logging.
# Usage: find_dead_code.sh [threshold] [path] [--exclude=path1,path2] [--verbose]
# Example: find_dead_code.sh 3 /path/to/project --exclude=tests,venv --verbose

# Default threshold for minimum occurrences
n="${1:-3}"
# Directory to search in, defaults to current directory
dir="${2:-.}"

excluded_paths=()
verbose_mode=false

shift 2
for arg in "$@"; do
    case $arg in
        --exclude=*)
            IFS=',' read -r -a excluded_paths <<< "${arg#*=}"
            ;;
        --verbose)
            verbose_mode=true
            ;;
        *)
            echo "Warning: Unrecognized option '$arg'"
            ;;
    esac
done

if [ ! -d "$dir" ]; then
    echo "Error: Specified directory does not exist."
    exit 1
fi

# Function to recursively find all Python files in the specified directory
find_python_files() {
    find "$dir" -type f -name '*.py' | {
        for excluded_path in "${excluded_paths[@]}"; do
            grep -v "$dir/$excluded_path"
        done
    }
}

# Function to extract function and class names
extract_names() {
    local file
    while IFS= read -r file; do
        if $verbose_mode; then
            echo "Processing file: $file"
        fi
        grep -Eho '^class [a-zA-Z_][a-zA-Z0-9_]*|^def [a-zA-Z_][a-zA-Z0-9_]*' "$file" | awk '{print $2}'
    done < <(find_python_files) | sort | uniq
}

# Function to count occurrences and display names under threshold
count_and_display() {
    local name
    while IFS= read -r name; do
        if [[ $name =~ ^test ]]; then
            continue
        fi

        local count=$(grep -RhoP "\b${name}\b" "$dir" | wc -l)
        if [ "$count" -lt "$n" ]; then
            echo "$name occurred $count times"
        fi
    done
}

# Main execution
extract_names | count_and_display
