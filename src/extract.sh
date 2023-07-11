#!/usr/bin/env bash

# Script Name: extract.sh
# Description: Script to extract files based on extension
# Usage: extract.sh [archive file] [optional: output directory]
#       [archive file] - archive file to be extracted
# Example: ./extract.sh example-14-09-12.tar /home/user/output

extensions=(.tar.xz .tar.gz .tar.bz2 .tar .tgz .bz .bz2 .tbz .tbz2 .gz .zip .jar .Z .rar .7z)

main() {
    if [ $# -lt 1 ] || [ $# -gt 2 ]; then
        echo "Usage: extract.sh [archive file] [optional: output directory]"
        echo "       [archive file] - archive file to be extracted"
        echo "Example: ./extract.sh example-14-09-12.tar /home/user/output"
        exit 1
    fi

    file="$1"
    output_dir="${2:-.}"

    if ! [ -f "$file" ]; then
        echo "File $file does not exist."
        exit 1
    fi

    if ! [ -d "$output_dir" ]; then
        echo "Output directory $output_dir does not exist."
        exit 1
    fi

    case "$file" in
        *.tar.xz|*.tar.gz|*.tar.bz2|*.tar|*.tgz) tar -xvf "$file" -C "$output_dir" ;;
        *.bz|*.bz2|*.tbz|*.tbz2) bzip2 -d -k "$file" ;;
        *.gz) gunzip "$file" -c > "$output_dir" ;;
        *.zip|*.jar) unzip "$file" -d "$output_dir" ;;
        *.Z) zcat "$file" | tar -xvf - -C "$output_dir" ;;
        *.rar) rar x "$file" "$output_dir" ;;
        *.7z) 7z x "$file" -o"$output_dir" ;;
        *) echo "Unsupported archive format. Supported formats: ${extensions[*]}" ;;
    esac
}

main "$@"
