#!/usr/bin/env bash

# Script Name: script_aliaser.sh
# Description: Copies Bash scripts from a source directory to a destination directory, sets execution permissions, and adds them as aliases in the user's .bash_aliases file.
# Usage: ./script_aliaser.sh <source_dir> [destination_dir] [-v]
# Example: ./script_aliaser.sh /path/to/source /path/to/destination -v

verbose=false

log() {
    if [ "$verbose" = true ]; then
        echo "$1"
    fi
}

main() {
    # Validate the number of arguments
    if [ $# -lt 1 ] || [ $# -gt 3 ]; then
        echo "Error: Invalid number of arguments."
        echo "Usage: $0 <source_dir> [destination_dir] [-v]"
        exit 1
    fi

    # Validate the source directory
    if [ ! -d "$1" ]; then
        echo "Error: Source directory does not exist."
        exit 1
    fi

    # Set variables
    local source_dir="$1"
    local destination_dir="${2:-$HOME/.bash_scripts}"
    local alias_file="$HOME/.bash_aliases"

    # Check if verbose flag is set
    if [[ "$2" == "-v" ]] || [[ "$3" == "-v" ]]; then
        verbose=true
    fi

    # Create destination directory if it doesn't exist
    mkdir -p "$destination_dir"

    log "Copying scripts and setting execution permissions..."
    # Copy scripts and set execution permissions
    find "$source_dir" -name "*.sh" -exec cp {} "$destination_dir" \; -exec chmod +x "$destination_dir/{}" \;

    log "Adding aliases to $alias_file..."
    # Add aliases to .bash_aliases
    for file in "$destination_dir"/*.sh; do
        local alias_name
        alias_name=$(basename "$file" .sh)

        # Check if alias already exists
        if grep -q "^alias $alias_name=" "$alias_file"; then
            log "Alias $alias_name already exists, skipping."
        else
            # Add alias to .bash_aliases
            echo "alias $alias_name=\". $file\"" >> "$alias_file"
            log "Added alias: $alias_name -> $file"
        fi
    done

    echo "Installation successful! Bash scripts have been installed and aliased."
    echo "Please source your .bashrc or .bash_aliases to apply changes: . $alias_file"
}

main "$@"
