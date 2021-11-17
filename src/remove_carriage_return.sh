#!/usr/bin/env bash

# Script Name: remove_carriage_return.sh
# Description: Removes the carriage return from all the files in a given directory.
# Usage: remove_carriage_return.sh [<directory_path>]
#        [<directory_path>] - the path to the directory to process.
# Example: ./remove_carriage_return.sh path/to/directory

remove_carriage_return ()
{
    sed -i 's/\r//g' $1
}

main() {

    if [ $# -eq 0 ]; then
        echo "Must provide a path!"
        exit 1
    fi

    if [ $1 == '.' ] || [ -d "${1}" ]; then
        for file in $(find $1 -maxdepth 10 -type f)
        do
            remove_carriage_return $file
        done
    elif [ -f "${1}" ]; then
        remove_carriage_return $1
    else
        echo "$1 is not a valid path!"
    fi

}

main "$@"
