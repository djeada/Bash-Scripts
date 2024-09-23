#!/usr/bin/env bash

# Script Name: script_aliaser.sh
# Description: Copies Bash scripts from a source directory to a destination directory,
#              sets execution permissions, and adds them as aliases in the user's .bash_aliases file.
# Usage: ./script_aliaser.sh -s <source_dir> [-d <destination_dir>] [-v]
# Example: ./script_aliaser.sh -s /path/to/source -d /path/to/destination -v

set -euo pipefail

# Default values
verbose=false
destination_dir="$HOME/.bash_scripts"
alias_file="$HOME/.bash_aliases"

usage() {
    echo "Usage: $0 -s <source_dir> [-d <destination_dir>] [-v]"
    echo "Options:"
    echo "  -s <source_dir>       Specify the source directory containing scripts (required)."
    echo "  -d <destination_dir>  Specify the destination directory (default: $destination_dir)."
    echo "  -v                    Enable verbose output."
    echo "  -h                    Display this help message."
    exit 1
}

log() {
    if [ "$verbose" = true ]; then
        echo "$1"
    fi
}

main() {
    # Parse options
    while getopts ":s:d:vh" opt; do
        case $opt in
            s)
                source_dir="$OPTARG"
                ;;
            d)
                destination_dir="$OPTARG"
                ;;
            v)
                verbose=true
                ;;
            h)
                usage
                ;;
            \?)
                echo "Invalid option: -$OPTARG" >&2
                usage
                ;;
            :)
                echo "Option -$OPTARG requires an argument." >&2
                usage
                ;;
        esac
    done

    # Check if source directory is set
    if [ -z "${source_dir:-}" ]; then
        echo "Error: Source directory is required."
        usage
    fi

    # Validate the source directory
    if [ ! -d "$source_dir" ]; then
        echo "Error: Source directory '$source_dir' does not exist."
        exit 1
    fi

    # Create destination directory if it doesn't exist
    mkdir -p "$destination_dir"

    log "Copying scripts from '$source_dir' to '$destination_dir' and setting execution permissions..."

    # Copy scripts and set execution permissions
    while IFS= read -r -d '' script_file; do
        script_name=$(basename "$script_file")
        dest_file="$destination_dir/$script_name"

        cp "$script_file" "$dest_file"
        chmod +x "$dest_file"

        log "Copied and set permissions: $dest_file"
    done < <(find "$source_dir" -type f -name "*.sh" -print0)

    # Ensure .bash_aliases file exists
    touch "$alias_file"

    log "Adding aliases to '$alias_file'..."

    # Add aliases to .bash_aliases
    while IFS= read -r -d '' script_file; do
        script_name=$(basename "$script_file")
        alias_name="${script_name%.*}"
        dest_file="$destination_dir/$script_name"

        # Check if alias already exists
        if grep -q "^alias $alias_name=" "$alias_file"; then
            log "Alias '$alias_name' already exists, skipping."
        else
            # Add alias to .bash_aliases
            echo "alias $alias_name='$dest_file'" >> "$alias_file"
            log "Added alias: $alias_name -> $dest_file"
        fi
    done < <(find "$destination_dir" -type f -name "*.sh" -print0)

    echo "Installation successful! Bash scripts have been installed and aliased."
    echo "Please source your .bashrc or .bash_aliases to apply changes: source $alias_file"
}

main "$@"
