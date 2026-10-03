#!/usr/bin/env bash

# Script Name: replace_everywhere.sh
# Description: Replaces string a with string b (literally, not as a regex) in all text files
#              in the current directory and subdirectories. Binary files and files that
#              don't contain string a are left untouched.
#              Skips hidden files and directories by default. Optionally excludes specific subdirectories.
# Usage: ./replace_everywhere.sh [options] <string_a> <string_b>
# Options:
#   -x, --exclude DIR    Exclude a subdirectory (repeatable).
#       --include-hidden Include hidden files and directories (like .git, .venv).
#   -y, --yes            Skip confirmation prompt.
#   -h, --help           Show help and exit.
# Examples:
#   ./replace_everywhere.sh "cat" "dog"
#   ./replace_everywhere.sh -x dist -x build 'old' 'new'

set -euo pipefail

print_usage() {
    # Print the header comment block (everything up to the first non-comment line)
    sed -n '3,/^[^#]/{/^#/s/^# \{0,1\}//p}' "$0"
}

# Escape a string for use as a *literal* sed pattern (s/…/…/)
escape_sed_pattern() {
    printf '%s' "$1" | sed -e 's/[.[\*^$\/]/\\&/g' -e 's/]/\\]/g'
}

# Escape replacement for sed (so '&' doesn't expand to the whole match)
escape_sed_replacement() {
    local s=$1
    s=${s//\\/\\\\}   # escape backslashes first
    s=${s//&/\\&}     # then ampersands
    s=${s//\//\\/}    # and the '/' delimiter
    printf '%s' "$s"
}

main() {
    local include_hidden=false
    local auto_yes=false
    local -a excludes=()

    # Parse args (support short and long)
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -x|--exclude)
                [[ $# -lt 2 ]] && { echo "Missing argument for $1" >&2; exit 2; }
                excludes+=("$2"); shift 2 ;;
            --include-hidden)
                include_hidden=true; shift ;;
            -y|--yes)
                auto_yes=true; shift ;;
            -h|--help)
                print_usage; exit 0 ;;
            --) shift; break ;;
            -*)
                echo "Unknown option: $1" >&2; print_usage; exit 2 ;;
            *)
                break ;;
        esac
    done

    if [[ $# -ne 2 ]]; then
        print_usage
        exit 1
    fi

    local search_raw="$1"
    local replace_raw="$2"

    if [[ -z "$search_raw" ]]; then
        echo "Error: the search string must not be empty." >&2
        exit 1
    fi
    if [[ "$search_raw" == *$'\n'* || "$replace_raw" == *$'\n'* ]]; then
        echo "Error: multi-line strings are not supported." >&2
        exit 1
    fi

    local search replace
    search=$(escape_sed_pattern "$search_raw")
    replace=$(escape_sed_replacement "$replace_raw")

    # Confirm action unless -y/--yes
    if [[ "$auto_yes" == false ]]; then
        read -r -p "Replace ALL occurrences of '$search_raw' with '$replace_raw' in this tree? [y/N] " confirmation
        if [[ ! $confirmation =~ ^[Yy]$ ]]; then
            echo "Operation cancelled."
            exit 1
        fi
    fi

    # Detect GNU vs BSD sed for in-place flag
    local -a SED_INPLACE
    if sed --version >/dev/null 2>&1; then
        SED_INPLACE=(-i)
    else
        SED_INPLACE=(-i '')
    fi

    # Build the find prune predicates
    local -a PRUNE_BLOCK=()
    if [[ "$include_hidden" == false ]]; then
        PRUNE_BLOCK+=( -name '.*' ! -name . -prune -o )
    fi

    if [[ ${#excludes[@]} -gt 0 ]]; then
        for d in "${excludes[@]}"; do
            d="${d%/}"
            [[ "$d" != ./* ]] && d="./$d"
            PRUNE_BLOCK+=( -path "$d" -prune -o )
        done
    fi

    # Only rewrite text files that actually contain the search string
    # (grep -I skips binary files, -F matches literally, -Z/-0 handle any file name)
    local -a find_cmd=(find . \( "${PRUNE_BLOCK[@]}" -false \) -o -type f -exec grep -lIZF -e "$search_raw" -- {} +)
    local -a files=()
    local f
    while IFS= read -r -d '' f; do
        files+=("$f")
    done < <("${find_cmd[@]}" 2>/dev/null)

    if [[ ${#files[@]} -eq 0 ]]; then
        echo "No files contain '$search_raw'."
        exit 0
    fi

    for f in "${files[@]}"; do
        sed "${SED_INPLACE[@]}" "s/${search}/${replace}/g" "$f"
        echo "Updated: $f"
    done

    echo "Done. ${#files[@]} file(s) updated."
}

main "$@"

