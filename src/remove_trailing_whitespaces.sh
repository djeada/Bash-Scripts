#!/usr/bin/env bash

remove_trailing_whitespaces() {
    local file="$1"

    touch  "${file}".tmp
    echo "Checking each line of ${file} for trailing whitespaces..."

    while IFS= read -r line; do
        if [[ $line == *[[:space:]] ]]; then
            echo "Found trailing whitespaces in line: ${line}"
            echo "${line}" | sed 's/[ \t]*$//' >> "${file}".tmp
        else
            echo "${line}"  >> "${file}".tmp
        fi
    done < <(grep '' "${file}")

    mv "${file}.tmp" "${file}"

    echo "Done!"
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
            remove_trailing_whitespaces $file
        done
    elif [ -f "${1}" ]; then
        remove_trailing_whitespaces $1
    else
        echo "$1 is not a valid path!"
    fi

}

main "$@"
