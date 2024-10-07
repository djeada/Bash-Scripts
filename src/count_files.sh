#!/usr/bin/env bash

# Script Name: count_files.sh
# Description: Counts the number of directories, files, and total count in a specified directory,
#              with options to filter by extension and set traversal depth.
# Usage: count_files.sh [--directory <dir>] [--depth <depth>] [--extension <ext>] [--help]
#        --directory <dir>   (optional) - the directory to count files in (default: current directory)
#        --depth <depth>     (optional) - the maximum depth of directory traversal (default: unlimited)
#        --extension <ext>   (optional) - only count files with the specified extension
#        --help              (optional) - display this help message
# Example:
#   ./count_files.sh
#   ./count_files.sh --directory /path/to/dir --depth 2 --extension txt

set -euo pipefail

show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
  -d, --directory DIR     The directory to count files in (default: current directory)
  -p, --depth DEPTH       The maximum depth of directory traversal (default: unlimited)
  -e, --extension EXT     Only count files with the specified extension
  -h, --help              Display this help message

Examples:
  $0
  $0 --directory /path/to/dir --depth 2 --extension txt
EOF
    exit 0
}

count_files() {
    local dir="$1"
    local depth="$2"
    local extension="$3"

    if [[ ! -d "$dir" ]]; then
        echo "Error: Directory '$dir' does not exist."
        exit 1
    fi

    echo -e "\nCounting files in directory: $dir"
    [[ -n "$depth" ]] && echo "Depth: $depth"
    [[ -n "$extension" ]] && echo "Filtering by extension: .$extension"

    local find_cmd=(find "$dir")
    [[ -n "$depth" ]] && find_cmd+=(-maxdepth "$depth")
    [[ -n "$extension" ]] && find_cmd+=(-name "*.$extension")
    find_cmd+=(-type f)

    local num_files
    num_files=$( "${find_cmd[@]}" | wc -l )

    local num_dirs
    num_dirs=$( find "$dir" ${depth:+-maxdepth "$depth"} -type d | wc -l )

    local total_count=$((num_dirs + num_files))

    echo "Number of directories: $num_dirs"
    echo "Number of files: $num_files"
    echo "Total count: $total_count"
}

main() {
    local dir="$(pwd)"
    local depth=""
    local extension=""

    # Parse options
    options=$(getopt -o d:p:e:h --long directory:,depth:,extension:,help -n "$0" -- "$@")
    eval set -- "$options"

    while true; do
        case "$1" in
            -d|--directory)
                dir="$2"
                shift 2
                ;;
            -p|--depth)
                depth="$2"
                shift 2
                ;;
            -e|--extension)
                extension="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                ;;
            --)
                shift
                break
                ;;
            *)
                echo "Invalid option: $1"
                show_help
                ;;
        esac
    done

    count_files "$dir" "$depth" "$extension"
}

main "$@"
