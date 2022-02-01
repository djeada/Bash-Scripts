#!/usr/bin/env bash

# Script Name: extract.sh
# Description: Script to extract files based on extension
# Usage: extract.sh [archive file]
#       [archive file] - archive file to be extracted
# Example: ./extract.sh example-14-09-12.tar

extensions=(.tar.xz .tar.gz .tar.bz2 .tar .tgz .bz .bz2 .tbz .tbz2 .gz .zip .jar .Z .rar)

main() {
    if [ $# -ne 1 ]; then
        echo "Usage: extract.sh [[archive file]"
        echo "       [archive file] - archive file to be extracted"
        echo "Example: ./extract.sh example-14-09-12.tar"
        exit 1
    fi

    output_dir='.'

    if
    [[ "$1" == *.tar.xz ]] ||
    [[ "$1" == *.tar.gz ]] ||
    [[ "$1" == *.tar.bz2 ]] ||
    [[ "$1" == *.tar ]] ||
    [[ "$1" == *.tgz ]]; then
        tar -xvf "$1" -C "$output_dir"
    elif
    [[ "$1" == *.bz ]] ||
    [[ "$1" == *.bz2 ]] ||
    [[ "$1" == *.tbz ]] ||
    [[ "$1" == *.tbz2 ]]; then
        bzip2 -d -k "$1"
    elif
    [[ "$1" == *.gz ]]; then
        gunzip "$1" -c > "$output_dir"
    elif
    [[ "$1" == *.zip ]] ||
    [[ "$1" == *.jar ]]; then
        unzip "$1" -d "$output_dir"
    elif
    [[ "$1" == *.Z ]]; then
        zcat "$1" | tar -xvf - -C "$output_dir"
    elif
    [[ "$1" == *.rar ]]; then
        rar x "$1" "$output_dir"
    else
        echo "Please specify a correct archive format: \"${extensions[*]}\""
    fi
}

main "$@"

