#!/usr/bin/env bash

# Script Name: line_counter.sh
# Description: Counts the number of lines in a file.
# Usage: line_counter.sh [<file_name>]
#        [<file_name>] - the name of the file to count the lines in.
# Example: ./line_counter.sh path/to/file.txt

main() {

    if [ -z "$1" ]
    then
        echo "No arguments supplied"
        exit 1
    fi

    file_name=$1

    if [ ! -f "$file_name" ]; then
        echo "$file_name does not exist."
        exit 1
    fi

    counter=0

    while read p; do
        ((counter++))
    done < $file_name

    echo "Number of lines in ${file_name} is: ${counter}"

}

main "$@"

