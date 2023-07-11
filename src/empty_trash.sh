#!/usr/bin/env bash

# Script Name: empty_trash.sh
# Description: Empties the trash.
# Usage: empty_trash.sh [optional: path to trash]
# Example: ./empty_trash.sh
#          ./empty_trash.sh /custom/path/to/trash

main() {
    if [ $# -eq 1 ]; then
        path=$1
    elif [ "$(uname)" == "Darwin" ]; then
        path=~/.Trash
        echo "Detected system: Mac OS X"
    elif [ "$(uname)" == "Linux" ]; then
        if [ -d ~/.local/share/Trash/files ]; then
            path=~/.local/share/Trash/files
        else
            echo "Cannot find the default trash directory. Please specify the path of the directory you wish to empty."
            exit 1
        fi
    else
        echo "Unsupported system detected. Please specify the path of the directory you wish to empty."
        exit 1
    fi

    echo "Attempting to remove files located at: $path"

    if [ -d "$path" ]; then
        if [ -w "$path" ]; then
            rm -rf "${path:?}"/* && echo "Trash emptied successfully" || echo "Failed to empty trash"
        else
            echo "You do not have write permissions to the specified directory."
            exit 1
        fi
    else
        echo "The specified directory does not exist."
        exit 1
    fi
}

main "$@"
