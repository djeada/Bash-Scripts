#!/usr/bin/env bash

# Script Name: count_files.sh
# Description: Counts the number of directories, files, and total count in a specified directory,
#              with options to filter by extension and set traversal depth.
#              The starting directory itself is not counted.
# Usage: count_files.sh [-d|--directory <dir>] [-p|--depth <depth>] [-e|--extension <ext>] [-h|--help]
#        --directory <dir>   (optional) - the directory to count files in (default: current directory)
#        --depth <depth>     (optional) - the maximum depth of directory traversal (default: unlimited)
#        --extension <ext>   (optional) - only count files with the specified extension (e.g. txt)
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
}

count_files() {
    local dir="$1"
    local depth="$2"
    local extension="$3"

    if [[ ! -d "$dir" ]]; then
        echo "Error: Directory '$dir' does not exist." >&2
        exit 1
    fi

    echo -e "\nCounting files in directory: $dir"
    [[ -n "$depth" ]] && echo "Depth: $depth"
    [[ -n "$extension" ]] && echo "Filtering by extension: .$extension"

    local find_opts=(-mindepth 1)
    [[ -n "$depth" ]] && find_opts+=(-maxdepth "$depth")

    local name_filter=()
    [[ -n "$extension" ]] && name_filter=(-name "*.$extension")

    # Print one character per match so file names containing newlines count once.
    local num_files
    num_files=$(find "$dir" "${find_opts[@]}" -type f "${name_filter[@]}" -printf '.' | wc -c)

    local num_dirs
    num_dirs=$(find "$dir" "${find_opts[@]}" -type d -printf '.' | wc -c)

    local total_count
    total_count=$((num_dirs + num_files))

    echo "Number of directories: $num_dirs"
    echo "Number of files: $num_files"
    echo "Total count: $total_count"
}

main() {
    local dir
    dir="$(pwd)"
    local depth=""
    local extension=""

    # Parse options
    local options
    if ! options=$(getopt -o d:p:e:h --long directory:,depth:,extension:,help -n "$0" -- "$@"); then
        show_help >&2
        exit 1
    fi
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
                exit 0
                ;;
            --)
                shift
                break
                ;;
            *)
                echo "Invalid option: $1" >&2
                show_help >&2
                exit 1
                ;;
        esac
    done

    if [[ $# -gt 0 ]]; then
        echo "Unexpected argument: $1" >&2
        show_help >&2
        exit 1
    fi

    if [[ -n "$depth" && ! "$depth" =~ ^[0-9]+$ ]]; then
        echo "Error: Depth must be a non-negative integer." >&2
        exit 1
    fi
    extension="${extension#.}"

    count_files "$dir" "$depth" "$extension"
}

main "$@"

