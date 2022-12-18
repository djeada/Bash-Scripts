#!/usr/bin/env bash

# Copy all the scripts to ~/.bash_scripts
# Make sure they have proper permissions set
# Loop over the scripts and for each one create an alias in ~/.bashrc


main() {

    # check if at least one argument is given
    if [ $# -eq 0 ]; then
        echo "Usage: $0 <source_dir> [destination_dir]"
        exit 1
    fi

    # check if source directory exists
    if [ ! -d "$1" ]; then
        echo "Source directory does not exist"
        exit 1
    fi

    local source_dir="$1"
    if [ $# -gt 1 ]; then
        local destination_dir="$2"
    else
        local destination_dir="$HOME/.bash_scripts"
    fi

    # create destination directory if it does not exist
    mkdir -p "$destination_dir"

    # copy all files with .sh extension from source directory to destination directory
    cp -r "$source_dir"/*.sh "$destination_dir"

    # add execute permissions to all files
    chmod +x "$destination_dir"/*.sh

    # put aliases to all .sh files from destination directory in .bashrc
    for file in "$destination_dir"/*.sh; do
        echo "alias $(basename "$file" .sh)=\"$file\"" >> "$HOME/.bashrc"
        echo "The following alias has been added to your .bashrc: $(basename "$file" .sh)=\"$file\""
    done

    # reload .bashrc
    source "$HOME/.bashrc"

    # print success message
    echo "Successfully installed bash scripts"

}

main "$@"

