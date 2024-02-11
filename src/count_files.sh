#!/usr/bin/env bash

# Script Name: count_files.sh
# Description: Counts the number of directories, files, and total count in a specified directory.
# Usage: count_files.sh [--directory <dir>] [--depth <depth>]
#        --directory <dir> (optional) - the directory to count files in
#        --depth <depth> (optional) - the maximum depth of directory traversal (default: 1)
# Example: ./count_files.sh
#          ./count_files.sh --directory /path/to/directory --depth 2

count_files() {
    local dir="$1"
    local depth="${2:-1}"

    if [ ! -d "$dir" ]; then
        echo "Error: Directory '$dir' does not exist."
        exit 1
    fi

    echo -e "\nCounting files in directory: $dir (Depth: $depth)"

    local num_dirs=$(find "$dir" -maxdepth "$depth" -type d | wc -l)
    local num_files=$(find "$dir" -maxdepth "$depth" -type f | wc -l)
    local total_count=$((num_dirs + num_files))

    echo "Number of directories: $num_dirs"
    echo "Number of files: $num_files"
    echo "Total count: $total_count"
}

main() {
    local dir=""
    local depth=""

    while getopts ":d:p:" opt; do
        case "$opt" in
            d) dir=$OPTARG ;;
            p) depth=$OPTARG ;;
            *) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
        esac
    done

    count_files "${dir:-$(pwd)}" "$depth"
}

main "$@"
