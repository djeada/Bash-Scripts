#!/usr/bin/env bash

# Script Name: empty_trash.sh
# Description: Empties the trash.
# Usage: empty_trash.sh
# Example: ./empty_trash.sh

main() {

    if [ $# -eq 1 ]; then
        path=$1

    elif [ $# -gt 1 ]; then
        echo "You can't provide more than one path!"
        exit 1

    elif [ "$(uname)" == "Darwin" ]; then
        path=~/.Trash
        echo "Detected system Mac Os X"

    elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
        distro=$(awk -F= '/^NAME/{print $2}' /etc/os-release)
        distro=$(echo "$distro" | awk '{print tolower($0)}')

        echo "Detected system $distro"

        if [[ $distro =~ "ubuntu"  || $distro =~ "mint" ]]; then
            path=~/.local/share/Trash/files
        else
            echo "You are using an unsupported system. You must specify the path of the directory you wish to empty."
            exit 1
        fi

    else
        echo "You are using an unsupported system. You must specify the path of the directory you wish to empty."
        exit 1
    fi

    echo "Attempting to remove files located at: $path"

    if [ -d "$path" ]; then
        rm -rf "$path"/*
        if [ $? -eq 0 ]; then
            echo OK
        else
            echo FAIL
        fi
    else
        echo "You are using a non-default trash location. You must specify the path of the directory you wish to empty."
        exit 1
    fi

}

main "$@"
