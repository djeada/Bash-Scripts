#!/usr/bin/env bash

correct_file_name ()
{
    new_name=`echo $1 | sed -e 's/ /_/g' | tr '[:upper:]' '[:lower:]'`
    mv "$1" "$new_name"
}

main() {

    if [ $# -eq 0 ]; then
        echo "Must provide the path!"
        exit 1
    fi

    if [ $1 == '.' ] || [ -d "${1}" ]; then
        for file in $(find $1 -maxdepth 10 -type f)
        do
            correct_file_name $file
        done
    elif [ -f "${1}" ]; then
        correct_file_name $1
    else
        echo "$1 is not a valid path!"
    fi

}

main "$@"
