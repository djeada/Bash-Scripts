#!/usr/bin/env bash

# Script Name: strip_cpp_comments.sh
# Description: Removes C/C++ comments from source files in place using pure Bash.
#              Supports directory scanning with configurable depth and file pattern matching.
#              Files given explicitly are always processed; directories (default: the
#              current one) are scanned for files whose path matches REGEX.
# Usage: ./strip_cpp_comments.sh [-r REGEX] [-n DEPTH] [path1 path2 ...]
# Options:
#   -r, --regex REGEX     Extended regexp for directory scanning (default: C/C++ extensions).
#   -n, --max-depth N     Recurse into directories at most N levels (default: 3, 0 = no recursion).
#   -h, --help            Show this help and exit.

set -euo pipefail
IFS=$'\n\t'

##############################################################################
# CONFIG
##############################################################################
DEFAULT_RE='\.([ch](pp|xx|c)?|cc|hh|hpp)$'   # .c .h .cpp .cc .cxx .hpp …
MAX_DEPTH=3                                  # default recursion depth

##############################################################################
# FUNCTION: strip_file  (comment-removal state machine)
#   A block comment is replaced by the newlines it contained (keeps line
#   numbers) or, if it had none, by one space (so "int/**/x" stays "int x").
##############################################################################
strip_file() {
    local file=$1
    local tmp
    tmp=$(mktemp "${TMPDIR:-/tmp}/scrub.XXXXXX") || { echo "Error: cannot create temp file" >&2; return 2; }

    # State machine variables
    local in_block=0 in_line=0 in_str=0 in_char=0 escape=0
    local prev='' c='' block_nl=''

    {
        while IFS= read -r -N1 c || [[ -n $c ]]; do
            # ---------- inside single-line comment ----------
            if (( in_line )); then
                if [[ $c == $'\n' ]]; then
                    in_line=0
                    printf '\n'
                fi
                continue
            fi

            # ---------- inside block comment ----------
            if (( in_block )); then
                if [[ $prev == '*' && $c == '/' ]]; then
                    in_block=0
                    prev=''
                    printf '%s' "${block_nl:- }"
                else
                    [[ $c == $'\n' ]] && block_nl+=$'\n'
                    prev=$c
                fi
                continue
            fi

            # ---------- inside string / character literal ----------
            if (( in_str || in_char )); then
                printf '%s' "$c"
                if (( escape )); then
                    escape=0
                elif [[ $c == \\ ]]; then
                    escape=1
                elif (( in_str )) && [[ $c == '"' ]]; then
                    in_str=0
                elif (( in_char )) && [[ $c == "'" ]]; then
                    in_char=0
                fi
                continue
            fi

            # ---------- previous char was '/' ----------
            if [[ -n $prev ]]; then
                prev=''
                case $c in
                    /) in_line=1; continue ;;                       # "//"
                    '*') in_block=1; block_nl=''; continue ;;       # "/*"
                    *) printf '/' ;;    # plain '/': c is handled below
                esac
            fi

            # ---------- neutral state ----------
            case $c in
                /) prev='/' ;;
                '"') in_str=1; printf '%s' "$c" ;;
                \') in_char=1; printf '%s' "$c" ;;
                *) printf '%s' "$c" ;;
            esac
        done < "$file"

        if [[ -n $prev ]]; then
            printf '%s' "$prev"        # lone '/' at end of file
        fi
    } > "$tmp" || { rm -f "$tmp"; return 2; }

    # Write back through the original file to keep its permissions and ownership
    if ! cat "$tmp" > "$file"; then
        echo "Error: cannot write $file" >&2
        rm -f "$tmp"
        return 2
    fi
    rm -f "$tmp"
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
                [[ $# -eq 0 || ! $1 =~ ^[0-9]+$ ]] && { echo "Error: -n needs a non-negative integer" >&2; exit 1; }
                depth=$1
                ;;
            -h|--help)
                sed -n '3,/^[^#]/{/^#/s/^# \{0,1\}//p}' "$0"
                exit 0
                ;;
            --)
                shift
                positional+=("$@")
                break
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

