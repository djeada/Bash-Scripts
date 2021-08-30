#!/usr/bin/env bash

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

