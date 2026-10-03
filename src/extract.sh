#!/usr/bin/env bash

# Script Name: extract.sh
# Description: Extracts files based on their extension. Single-file compressed
#              formats (.gz, .bz/.bz2, .Z) are decompressed into the output
#              directory, keeping the original file.
# Usage: extract.sh [archive file] [optional: output directory]

main() {
    if [ $# -lt 1 ] || [ $# -gt 2 ]; then
        echo "Usage: extract.sh [archive file] [optional: output directory]" >&2
        exit 1
    fi

    file="$1"
    output_dir="${2:-.}"

    if ! [ -f "$file" ]; then
        echo "File $file does not exist." >&2
        exit 1
    fi

    if ! [ -d "$output_dir" ]; then
        mkdir -p "$output_dir" || { echo "Failed to create output directory $output_dir" >&2; exit 1; }
        echo "Created output directory $output_dir"
    fi

    extract_file "$file" "$output_dir"
}

extract_file() {
    local file=$1
    local output_dir=$2
    local base
    base=$(basename "$file")

    case "$file" in
        *.tar.xz|*.tar.gz|*.tar.bz2|*.tar|*.tgz)
            command_exists "tar" && tar -xf "$file" -C "$output_dir" ;;
        *.tar.Z)  command_exists "zcat" && command_exists "tar" && zcat "$file" | tar -xf - -C "$output_dir" ;;
        *.bz|*.bz2) command_exists "bzip2" && bzip2 -dc "$file" > "$output_dir/${base%.*}" ;;
        *.gz)      command_exists "gunzip" && gunzip -c "$file" > "$output_dir/${base%.gz}" ;;
        *.Z)       command_exists "zcat" && zcat "$file" > "$output_dir/${base%.Z}" ;;
        *.zip|*.jar) command_exists "unzip" && unzip "$file" -d "$output_dir" ;;
        *.rar)
            if command -v unrar >/dev/null 2>&1; then
                unrar x "$file" "$output_dir/"
            else
                command_exists "rar" && rar x "$file" "$output_dir/"
            fi
            ;;
        *.7z)     command_exists "7z" && 7z x "$file" -o"$output_dir" ;;
        *) echo "Unsupported archive format: $file" >&2; exit 1 ;;
    esac
}

command_exists() {
    command -v "$1" >/dev/null 2>&1 || { echo >&2 "I require $1 but it's not installed. Aborting."; exit 1; }
}

main "$@"

