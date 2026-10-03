#!/usr/bin/env bash

# Script Name: find_duplicate_files.sh
# Description: Finds files with identical content. Files are first grouped by
#              size and only same-sized candidates are hashed, so large trees
#              are scanned quickly. Each group of duplicates is printed as a
#              block separated by a blank line, together with wasted space.
# Usage: find_duplicate_files.sh [-m min_size] [-a] [directory...]
# Options:
#   -m min_size  Ignore files smaller than this many bytes (default: 1).
#   -a           Include hidden files and directories.
#   -h           Show this help message.
# Examples:
#   find_duplicate_files.sh ~/Pictures
#   find_duplicate_files.sh -m 1048576 ~/Downloads ~/Documents

set -euo pipefail

usage() {
    sed -n '3,/^$/p' "$0" | sed -e '/^$/d' -e 's/^# \{0,1\}//'
}

die() {
    echo "Error: $*" >&2
    exit 2
}

human_size() {
    numfmt --to=iec --suffix=B "$1" 2>/dev/null || echo "${1}B"
}

main() {
    local min_size=1 hidden=0
    local opt

    while getopts ":m:ah" opt; do
        case "$opt" in
            m) min_size="$OPTARG" ;;
            a) hidden=1 ;;
            h) usage; exit 0 ;;
            :) die "option -$OPTARG requires an argument" ;;
            *) die "unknown option -$OPTARG" ;;
        esac
    done
    shift $((OPTIND - 1))

    [[ $min_size =~ ^[0-9]+$ ]] || die "min_size must be a non-negative integer"
    command -v sha256sum >/dev/null 2>&1 || die "sha256sum (coreutils) is required"
    [[ $# -gt 0 ]] || set -- .
    local dir
    for dir in "$@"; do
        [[ -d $dir ]] || die "'$dir' is not a directory"
    done

    local -a prune=() size_filter=()
    ((hidden)) || prune=(-name '.?*' -prune -o)
    ((min_size > 0)) && size_filter=(-size +"$((min_size - 1))"c)

    # Pass 1: size<TAB>path for every regular file, keep only sizes seen more than once.
    # Pass 2: hash those candidates and group by hash.
    local groups wasted=0 count=0
    groups=$(
        find "$@" -mindepth 1 "${prune[@]}" -type f "${size_filter[@]}" -printf '%s\t%p\0' |
        awk 'BEGIN { RS = "\0"; ORS = "\0" }
                 { size = substr($0, 1, index($0, "\t") - 1); n[size]++; line[NR] = $0; sz[NR] = size }
                 END { for (i = 1; i <= NR; i++) if (n[sz[i]] > 1) print substr(line[i], index(line[i], "\t") + 1) }' |
        xargs -0 -r sha256sum |
        sort |
        awk '{ hash = substr($0, 1, 64); path = substr($0, 67)
                   if (hash == prev) { if (!open) { print ""; print prevpath; open = 1 } print path }
                   else open = 0
                   prev = hash; prevpath = path }'
    )

    if [[ -z $groups ]]; then
        echo "No duplicate files found."
        return 0
    fi

    printf '%s\n' "${groups#$'\n'}"

    # Summarise: every file in a group beyond the first is wasted space.
    local first=1 size line
    while IFS= read -r line; do
        if [[ -z $line ]]; then
            first=1
            continue
        fi
        if ((first)); then
            first=0
            count=$((count + 1))
            continue
        fi
        size=$(stat -c %s -- "$line")
        wasted=$((wasted + size))
    done <<<"$groups"

    echo
    echo "Found $count group(s) of duplicates; $(human_size "$wasted") could be reclaimed."
}

main "$@"

