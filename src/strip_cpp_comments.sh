#!/usr/bin/env bash
#
# strip_comments.sh  —  Remove C / C++ comments from files *in place* (pure Bash)
#
# Usage:
#   strip_comments.sh [-r REGEX] [file1 file2 …]
#
#   -r | --regex REGEX   Extended-regexp that candidate filenames must match.
#                        If you omit every file argument, the script looks in
#                        the current directory and processes *all* regular files
#                        that match REGEX.
#
# Default REGEX :  \.([ch](pp|xx|c)?|cc|hh|hpp)$   # .c .h .cpp .cc .cxx .hpp …
#
# Exit codes:
#   0  OK
#   1  bad usage / no files found
#   2  cannot read / write file
#

set -euo pipefail
IFS=$'\n\t'

##############################################################################
# CONFIG
##############################################################################
DEFAULT_RE='\.([ch](pp|xx|c)?|cc|hh|hpp)$'   # .c .h .cpp .cc .cxx .hpp …

##############################################################################
# FUNCTION: strip_file  (unchanged)
##############################################################################
strip_file() {
    local file=$1
    local tmp
    tmp=$(mktemp "${TMPDIR:-/tmp}/scrub.XXXXXX") || {
        echo "Error: cannot create temp file" >&2; return 2; }

    # State variables
    local in_block=0 in_line=0 in_str=0 in_char=0 escape=0
    local prev='' c=''

    # FD 3 → tmp
    exec 3> "$tmp"

    while IFS= read -r -N1 c || [[ -n $c ]]; do
        # ---------- end of line comment ----------
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

        # ---------- inside string ----------
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

        # ---------- inside character ----------
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

        # ---------- neutral ----------
        if [[ -z $prev ]]; then
            case $c in
                /)   prev='/' ;;                     # might start comment
                '"') in_str=1 ; printf '%s' "$c" >&3 ;;
                "'") in_char=1; printf '%s' "$c" >&3 ;;
                *)   printf '%s' "$c" >&3 ;;
            esac
        else
            case $c in
                /)  in_line=1 ; prev='' ;;           # "//"
                \*) in_block=1; prev='' ;;           # "/*"
                *)  printf '/%s' "$c" >&3; prev='' ;;
            esac
        fi
    done < "$file"

    [[ -n $prev ]] && printf '%s' "$prev" >&3     # lone '/'

    chmod --reference="$file" "$tmp"
    mv "$tmp" "$file"
}

##############################################################################
# FUNCTION: main  (argument logic updated)
##############################################################################
main() {
    local regex=$DEFAULT_RE
    local positional=()

    # ------ parse args ------
    while [[ $# -gt 0 ]]; do
        case $1 in
            -r|--regex)
                shift
                [[ $# -eq 0 ]] && { echo "Error: -r needs ARG" >&2; exit 1; }
                regex=$1
                ;;
            -*)
                echo "Unknown option: $1" >&2; exit 1 ;;
            *)
                positional+=("$1")
                ;;
        esac
        shift
    done

    # ------ auto-discover files if none listed ------
    if (( ${#positional[@]} == 0 )); then
        for f in *; do
            [[ -f $f && $f =~ $regex ]] && positional+=("$f")
        done
    fi

    (( ${#positional[@]} )) || { echo "Error: no files match '$regex'" >&2; exit 1; }

    # ------ process ------
    for f in "${positional[@]}"; do
        [[ $f =~ $regex ]] || { echo "Skip: $f (no match)" >&2; continue; }
        [[ -r $f && -w $f ]] || { echo "Error: cannot read/write $f" >&2; exit 2; }
        echo "Stripping comments from $f ..."
        strip_file "$f" || exit $?
    done

    echo "Done."
}

main "$@"
