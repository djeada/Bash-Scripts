#!/usr/bin/env bash

assert_last_line_empty() {
    local file="$1"

    echo "Checking if the last line of ${file} is empty..."

    local last_line=$(tail -n 1 "${file}")

    if [ -z "${last_line}" ]; then
        echo "Last line is empty!"
    else
        echo "Last line is not empty!"
        echo "${last_line}"
        echo "" >> "${file}"
    fi

}

main() {

    if [ $# -eq 0 ]; then
        echo "Must provide a path!"
        exit 1
    elif [ $# -gt 1 ]; then
        echo "Only one path is supported!"
        exit 1
    fi

    if [ "$1" == '.' ] || [ -d "${1}" ]; then
        for file in $(find $1 -maxdepth 10 -type f)
        do
            assert_last_line_empty $file
        done
    elif [ -f "${1}" ]; then
        assert_last_line_empty $1
    else
        echo "$1 is not a valid path!"
    fi

}

main "$@"

