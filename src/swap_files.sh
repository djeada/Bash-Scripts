#!/usr/bin/env bash

# Script Name: swap_files.sh
# Description: Swaps the contents of two files with additional options and safety checks.
#
# Usage: swap_files.sh [options] file1 file2
#
# Options:
#   -h, --help          Display this help message and exit.
#   -b, --backup        Create backups of the files before swapping.
#   -f, --force         Force swap even if files are the same.
#   -v, --verbose       Enable verbose output.
#
# Arguments:
#   file1               Path to the first file.
#   file2               Path to the second file.
#
# Examples:
#   ./swap_files.sh file1.txt file2.txt
#   ./swap_files.sh -b file1.txt file2.txt
#   ./swap_files.sh --force --verbose file1.txt file2.txt

set -euo pipefail

# Function to display the help message
function show_help() {
    grep '^#' "$0" | cut -c 4-
    exit 0
}

# Function to check if a file exists and is a regular file
function check_file_existence() {
    local file="$1"
    if [ ! -e "$file" ]; then
        echo "Error: File '$file' does not exist."
        exit 1
    fi
    if [ ! -f "$file" ]; then
        echo "Error: '$file' is not a regular file."
        exit 1
    fi
}

# Function to create a backup of a file
function create_backup() {
    local file="$1"
    local backup_file="${file}_backup_$(date +%Y%m%d%H%M%S)"
    cp -- "$file" "$backup_file"
    [ "$VERBOSE" = true ] && echo "Backup of '$file' created as '$backup_file'."
}

# Function to swap the contents of two files
function swap_file_contents() {
    local file1="$1"
    local file2="$2"

    # Check if both files are the same
    if [ "$(realpath "$file1")" = "$(realpath "$file2")" ] && [ "$FORCE" = false ]; then
        echo "Error: Cannot swap the same file. Use --force to override."
        exit 1
    fi

    local temp
    temp=$(mktemp)

    cp -- "$file1" "$temp"
    cp -- "$file2" "$file1"
    cp -- "$temp" "$file2"

    rm -- "$temp"
    [ "$VERBOSE" = true ] && echo "Swapped contents of '$file1' and '$file2'."
}

# Main function to parse arguments and execute script logic
function main() {
    # Default option values
    BACKUP=false
    FORCE=false
    VERBOSE=false

    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                ;;
            -b|--backup)
                BACKUP=true
                shift
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --)
                shift
                break
                ;;
            -*)
                echo "Unknown option: $1"
                show_help
                ;;
            *)
                break
                ;;
        esac
    done

    # Check for the correct number of arguments
    if [ $# -ne 2 ]; then
        echo "Error: Must provide exactly two file paths."
        show_help
    fi

    local file1="$1"
    local file2="$2"

    # Check if files exist
    check_file_existence "$file1"
    check_file_existence "$file2"

    # Create backups if requested
    if [ "$BACKUP" = true ]; then
        create_backup "$file1"
        create_backup "$file2"
    fi

    # Swap the file contents
    swap_file_contents "$file1" "$file2"

    echo "Contents of '$file1' and '$file2' have been swapped."
}

# Execute the main function with all script arguments
main "$@"
