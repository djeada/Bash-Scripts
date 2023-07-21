#!/usr/bin/env bash

# Global variables
checkonly=0
status=0
scriptname=$(basename "$0")

remove_trailing_whitespaces() {
    local file="$1"

    echo "Checking each line of ${file} for trailing whitespaces..."

    touch "${file}".tmp

    while IFS= read -r line; do
        if [[ $line == *[[:space:]] ]]; then
            echo "Found trailing whitespaces in line: ${line}"
            if [[ $checkonly -eq 0 ]]; then
                echo "${line}" | sed 's/[ \t]*$//' >> "${file}".tmp
            else
                status=1
            fi
        else
            if [[ $checkonly -eq 0 ]]; then
                echo "${line}" >> "${file}".tmp
            fi
        fi
    done < <(grep '' "${file}")

    if [[ $checkonly -eq 0 ]]; then
        mv "${file}".tmp "${file}"
        echo "Done!"
    fi
}

main() {
    if [[ $1 == "--check" ]]; then
        checkonly=1
        shift
    fi

    if [ $# -eq 0 ]; then
        echo "Must provide a path!"
        exit 1
    elif [ $# -gt 1 ]; then
        echo "Only one path is supported!"
        exit 1
    fi

    local path="$1"

    if [ "$path" == '.' ] || [ -d "$path" ]; then
        for file in $(find "$path" -maxdepth 10 -type f ! -name "*.tmp" ! -regex ".*/`basename "$0"`"); do

            remove_trailing_whitespaces "$file"
        done
    elif [ -f "$path" ]; then
        if [ "$(basename "$path")" != "$scriptname" ]; then
            remove_trailing_whitespaces "$path"
        fi
    else
        echo "$path is not a valid path!"
        exit 1
    fi

    if [[ $status -eq 1 ]]; then
        exit 1
    fi
}

main "$@"

