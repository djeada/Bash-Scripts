#!/usr/bin/env bash

# This script copies bash scripts from a source directory to a destination directory,
# grants them execution permissions and adds them as aliases in the user's .bashrc file.

# Function: Main script execution
main() {
    # Check if at least one argument is given
    if [ $# -eq 0 ]; then
        echo "Error: No arguments provided."
        echo "Usage: $0 <source_dir> [destination_dir]"
        exit 1
    fi

    # Validate source directory
    if [ ! -d "$1" ]; then
        echo "Error: Source directory does not exist."
        exit 1
    fi

    # Set source and destination directories
    local source_dir="$1"
    local destination_dir="${2:-$HOME/.bash_scripts}"

    # Create destination directory if it does not exist
    mkdir -p "$destination_dir"

    # Copy all .sh files from source directory to destination directory and set execution permissions
    echo "Copying scripts and setting execution permissions..."
    find "$source_dir" -name "*.sh" -exec cp {} "$destination_dir" \; -exec chmod +x {} \;

    # Add aliases to .bashrc for each .sh file in the destination directory
    echo "Adding aliases to .bashrc file..."
    for file in "$destination_dir"/*.sh; do
        local alias_name=$(basename "$file" .sh)
        echo "alias $alias_name=\". $file\"" >> "$HOME/.bashrc"
        echo "Added alias: $alias_name -> $file"
    done

    # Reload .bashrc
    echo "Reloading .bashrc file..."
    source "$HOME/.bashrc"

    # Print success message
    echo "Installation successful! Bash scripts have been installed and aliased."
}

main "$@"

