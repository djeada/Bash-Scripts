#!/usr/bin/env bash
#
# strip_comments.sh  —  Remove C / C++ comments from files *in place* (pure Bash)
#
# Usage:
#   strip_comments.sh [-r REGEX] [-n DEPTH] [path1 path2 …]
#
# Flags:
#   -r | --regex REGEX     Extended-regexp used **only** when scanning directories
#                          (default: see DEFAULT_RE below).
#   -n | --max-depth N     Recurse into directories at most N levels (default: 3).
#
# Behaviour:
#   • If a path is a **file** → always processed (regex ignored).  
#   • If a path is a **directory** (or none provided, so “.” is assumed) → search
#     for regular files ≤ DEPTH whose names match REGEX and process them.
#
# Exit codes:
#   0  success
#   1  bad usage / nothing found
#   2  cannot read or write a file
#

set -euo pipefail
IFS=$'\n\t'

##############################################################################
# CONFIG
##############################################################################
DEFAULT_RE='\.([ch](pp|xx|c)?|cc|hh|hpp)$'   # .c .h .cpp .cc .cxx .hpp …
MAX_DEPTH=3                                  # default recursion depth

##############################################################################
# FUNCTION: strip_file  (unchanged comment-removal FSM)
##############################################################################
strip_file() {
    local file=$1
    local tmp
    tmp=$(mktemp "${TMPDIR:-/tmp}/scrub.XXXXXX") || {
        echo "Error: cannot create temp file" >&2; return 2; }

    # State machine variables
    local in_block=0 in_line=0 in_str=0 in_char=0 escape=0
    local prev='' c=''

    exec 3> "$tmp"

    while IFS= read -r -N1 c || [[ -n $c ]]; do
        # ---------- end of single-line comment ----------
        if (( in_line )); then
            if [[ $c == $'\n' ]]; then
                in_line=0
                printf '\n' >&3
            fi
            continue
        fi

        # ---------- end of block comment ----------
        if (( in_block )); then
            if [[ $prev == '*' && $c == '/' ]]; then
                in_block=0
                prev=''
            else
                prev=$c
            fi
            continue
        fi

        # ---------- inside string literal ----------
        if (( in_str )); then
            printf '%s' "$c" >&3
            if (( escape )); then
                escape=0
            elif [[ $c == '\' ]]; then
                escape=1
            elif [[ $c == '"' ]]; then
                in_str=0
            fi
            continue
        fi

        # ---------- inside character literal ----------
        if (( in_char )); then
            printf '%s' "$c" >&3
            if (( escape )); then
                escape=0
            elif [[ $c == '\' ]]; then
                escape=1
            elif [[ $c == "'" ]]; then
                in_char=0
            fi
            continue
        fi

        # ---------- neutral state ----------
        if [[ -z $prev ]]; then
            case $c in
                /)   prev='/' ;;                      # possible comment start
                '"') in_str=1 ; printf '%s' "$c" >&3 ;;
                "'") in_char=1; printf '%s' "$c" >&3 ;;
                *)   printf '%s' "$c" >&3 ;;
            esac
        else
            case $c in
                /)  in_line=1 ; prev='' ;;            # "//"
                \*) in_block=1; prev='' ;;            # "/*"
                *)  printf '/%s' "$c" >&3; prev='' ;;
            esac
        fi
    done < "$file"

    [[ -n $prev ]] && printf '%s' "$prev" >&3        # lone '/'

    chmod --reference="$file" "$tmp"
    mv "$tmp" "$file"
}

##############################################################################
# FUNCTION: collect_from_dir
#   Recursively (≤ depth) add matching files from DIR into array COLLECTED[*]
##############################################################################
collect_from_dir() {
    local dir=$1 depth=$2 regex=$3
    local path rel depth_now

    shopt -s globstar nullglob
    for path in "$dir"/**; do
        [[ -f $path ]] || continue
        # Calculate relative depth
        rel=${path#"$dir"/}
        # Count slashes → depth
        depth_now=${rel//[^\/]/}
        depth_now=${#depth_now}
        (( depth_now <= depth )) || { continue; }
        [[ $path =~ $regex ]] && COLLECTED+=("$path")
    done
    shopt -u globstar nullglob
}

##############################################################################
# FUNCTION: main
##############################################################################
main() {
    local regex=$DEFAULT_RE
    local depth=$MAX_DEPTH
    local positional=()

    # -------- argument parsing --------
    while [[ $# -gt 0 ]]; do
        case $1 in
            -r|--regex)
                shift
                [[ $# -eq 0 ]] && { echo "Error: -r needs ARG" >&2; exit 1; }
                regex=$1
                ;;
            -n|--max-depth)
                shift
                [[ $# -eq 0 || ! $1 =~ ^[0-9]+$ ]] && {
                    echo "Error: -n needs positive integer" >&2; exit 1; }
                depth=$1
                ;;
            -*)
                echo "Unknown option: $1" >&2; exit 1 ;;
            *)
                positional+=("$1")
                ;;
        esac
        shift
    done

    # -------- build list of files to process --------
    declare -a COLLECTED=()

    if (( ${#positional[@]} == 0 )); then
        # No paths ⇒ current dir as implicit directory
        collect_from_dir "." "$depth" "$regex"
    else
        for p in "${positional[@]}"; do
            if [[ -f $p ]]; then
                COLLECTED+=("$p")                         # file ⇒ always keep
            elif [[ -d $p ]]; then
                collect_from_dir "$p" "$depth" "$regex"   # directory ⇒ filter
            else
                echo "Warning: $p is neither file nor directory" >&2
            fi
        done
    fi

    (( ${#COLLECTED[@]} )) || { echo "Error: nothing to do" >&2; exit 1; }

    # -------- process each collected file --------
    for f in "${COLLECTED[@]}"; do
        [[ -r $f && -w $f ]] || { echo "Error: cannot read/write $f" >&2; exit 2; }
        echo "Stripping comments from $f ..."
        strip_file "$f" || exit $?
    done

    echo "Done."
}

main "$@"
