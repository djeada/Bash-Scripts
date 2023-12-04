#!/usr/bin/env bash

# Script Name: extract.sh
# Description: Extracts files based on their extension.
# Usage: extract.sh [archive file] [optional: output directory]

main() {
    if [ $# -lt 1 ] || [ $# -gt 2 ]; then
        echo "Usage: extract.sh [archive file] [optional: output directory]"
        exit 1
    fi

    file="$1"
    output_dir="${2:-.}"

    if ! [ -f "$file" ]; then
        echo "File $file does not exist."
        exit 1
    fi

    if ! [ -d "$output_dir" ]; then
        mkdir -p "$output_dir" || { echo "Failed to create output directory $output_dir"; exit 1; }
        echo "Created output directory $output_dir"
    fi

    extract_file "$file" "$output_dir"
}

extract_file() {
    local file=$1
    local output_dir=$2

    case "$file" in
        *.tar.xz)  command_exists "tar" && tar -xvf "$file" -C "$output_dir" ;;
        *.tar.gz)  command_exists "tar" && tar -xzf "$file" -C "$output_dir" ;;
        *.tar.bz2) command_exists "tar" && tar -xjf "$file" -C "$output_dir" ;;
        *.tar)     command_exists "tar" && tar -xf "$file" -C "$output_dir" ;;
        *.tgz)     command_exists "tar" && tar -xzf "$file" -C "$output_dir" ;;
        *.bz|*.bz2) command_exists "bzip2" && bzip2 -d -k "$file" ;;
        *.gz)      command_exists "gunzip" && gunzip "$file" -c > "$output_dir" ;;
        *.zip|*.jar) command_exists "unzip" && unzip "$file" -d "$output_dir" ;;
        *.Z)      command_exists "zcat" && zcat "$file" | tar -xvf - -C "$output_dir" ;;
        *.rar)    command_exists "rar" && rar x "$file" "$output_dir" ;;
        *.7z)     command_exists "7z" && 7z x "$file" -o"$output_dir" ;;
        *) echo "Unsupported archive format." ;;
    esac
}

command_exists() {
    command -v "$1" >/dev/null 2>&1 || { echo >&2 "I require $1 but it's not installed. Aborting."; exit 1; }
}

main "$@"
