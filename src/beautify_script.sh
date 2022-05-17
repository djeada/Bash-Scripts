#!/usr/bin/env bash

format() {
    beautysh "$1"/**/*.sh
    shellcheck "$1"/**/*.sh
}

main() {


    if [ $# -eq 0 ]; then
        echo "Must provide a path!"
        exit 1
    fi

    if [ $1 == '.' ] || [ -d "${1}" ]; then
        for file in $(find $1 -maxdepth 10 -type f)
        do
            format $file
        done
    elif [ -f "${1}" ]; then
        format $1
    else
        echo "$1 is not a valid path!"
    fi


}

main "$@"
