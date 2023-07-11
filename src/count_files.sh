#!/usr/bin/env bash

# Script Name: count_files.sh
# Description: Counts the number of directories, files, and total count in a specified directory, current directory, home directory, and root directory with a specified depth.
# Usage: count_files.sh [--directory <dir>] [--depth <depth>]
#        --directory <dir> (optional) - the directory to count files in
#        --depth <depth> (optional) - the maximum depth of directory traversal (default: 1)
# Example: ./count_files.sh
#          ./count_files.sh --directory /path/to/directory --depth 2

count_files() {
    local dir="$1"
    local depth="$2"

    if [[ -z "$dir" ]]; then
        dir="."
    fi

    if [[ -z "$depth" ]]; then
        depth=1
    fi

    echo -e "\nCounting files in directory: $dir"

    local num_dirs=$(find "$dir" -maxdepth "$depth" -type d | wc -l)
    local num_files=$(find "$dir" -maxdepth "$depth" -type f | wc -l)
    local total_count=$((num_dirs + num_files))

    echo "Number of directories: $num_dirs"
    echo "Number of files: $num_files"
    echo "Total count: $total_count"
}

main() {
    local current_dir="$(pwd)"
    local home_dir="$HOME"
    local root_dir="/"
    local specified_dir=""
    local specified_depth=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --directory)
                specified_dir="$2"
                shift 2
                ;;
            --depth)
                specified_depth="$2"
                shift 2
                ;;
            *)
                echo "Invalid option: $1"
                exit 1
                ;;
        esac
    done

    if [[ -n "$specified_dir" ]]; then
        count_files "$specified_dir" "$specified_depth"
    else
        count_files "$current_dir" "$specified_depth"
        count_files "$home_dir" "$specified_depth"
        count_files "$root_dir" "$specified_depth"
    fi
}

main "$@"
