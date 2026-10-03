#!/usr/bin/env bash

# Script Name: find_large_files.sh
# Description: Lists the largest files (or directories) under a path, sorted
#              by size, to quickly find what is eating disk space.
# Usage: find_large_files.sh [-n count] [-s min_size] [-d] [-x] [path]
# Options:
#   -n count     Number of entries to show (default: 20).
#   -s min_size  Only show files at least this big, using find's size syntax
#                such as 100M or 2G (default: no limit).
#   -d           Rank directories by total size instead of individual files.
#   -x           Stay on the filesystem of the given path.
#   -h           Show this help message.
# Examples:
#   find_large_files.sh ~
#   find_large_files.sh -n 10 -s 500M /var
#   find_large_files.sh -d -x /

set -euo pipefail

usage() {
    sed -n '3,/^$/p' "$0" | sed -e '/^$/d' -e 's/^# \{0,1\}//'
}

die() {
    echo "Error: $*" >&2
    exit 2
}

main() {
    local count=20 min_size="" dirs=0 one_fs=0
    local opt

    while getopts ":n:s:dxh" opt; do
        case "$opt" in
            n) count="$OPTARG" ;;
            s) min_size="$OPTARG" ;;
            d) dirs=1 ;;
            x) one_fs=1 ;;
            h) usage; exit 0 ;;
            :) die "option -$OPTARG requires an argument" ;;
            *) die "unknown option -$OPTARG" ;;
        esac
    done
    shift $((OPTIND - 1))

    local path="${1:-.}"
    [[ -d $path ]] || die "'$path' is not a directory"
    [[ $count =~ ^[1-9][0-9]*$ ]] || die "count must be a positive integer"
    [[ -z $min_size || $min_size =~ ^[0-9]+[kMG]?$ ]] || die "min_size must look like 500k, 100M or 2G"

    if ((dirs)); then
        local -a du_opts=(--block-size=1 --max-depth=1)
        ((one_fs)) && du_opts+=(-x)
        du "${du_opts[@]}" -- "$path" 2>/dev/null |
        sort -rn |
        head -n "$((count + 1))" |
        numfmt --to=iec --suffix=B --padding=8 --field=1 --delimiter=$'\t'
        return 0
    fi

    local -a find_opts=()
    ((one_fs)) && find_opts+=(-xdev)
    [[ -n $min_size ]] && find_opts+=(-size "+$min_size")

    find "$path" "${find_opts[@]}" -type f -printf '%s\t%p\n' 2>/dev/null |
    sort -rn -t $'\t' -k1,1 |
    head -n "$count" |
    numfmt --to=iec --suffix=B --padding=8 --field=1 --delimiter=$'\t'
}

main "$@"

