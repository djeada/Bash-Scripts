#!/usr/bin/env bash

# Script Name: correct_file_names.sh
# Description: This script corrects file names in a specified directory by replacing all non-alphanumeric characters
#              (excluding dots) with underscores, converting repeated underscores to a single underscore, and making the names lowercase.
#              Additionally, it provides an option to include hidden directories.
# Usage: correct_file_names.sh [-a] [-e <file1,file2,...>] <directory>
#        -a: Include hidden directories (default is false).
#        -e: Comma-separated list of file names to exclude from modification (default is 'README.md').
#        <directory>: The directory containing the files to be corrected.
# Example: ./correct_file_names.sh -a -e README.md,path/to/file.txt path/to/directory

sanitize_basename() {
    # Transform only a basename (no path separators) according to the rules
    # - replace non-alnum except dot and underscore with underscore
    # - squeeze consecutive underscores
    # - lowercase
    # - trim leading/trailing underscores
    local name="$1"
    name=$(echo "$name" | sed -e 's/[^a-zA-Z0-9._]/_/g')
    name=$(echo "$name" | tr -s '_')
    name=$(echo "$name" | tr '[:upper:]' '[:lower:]')
    name=$(echo "$name" | sed -e 's/^_//g' -e 's/_$//g')
    printf '%s' "$name"
}

ensure_unique_target() {
    # Ensure target basename is unique within directory; append _1, _2, ... if needed
    local dir="$1"
    local base="$2"
    local candidate="$base"
    local i=1

    # split into name and extension (only if not a dotfile like .env)
    local name_noext="$base"
    local ext=""
    if [[ "$base" == *.* && "$base" != .* ]]; then
        name_noext="${base%.*}"
        ext=".${base##*.}"
    fi

    while [ -e "$dir/$candidate" ]; do
        candidate="${name_noext}_${i}${ext}"
        i=$((i+1))
    done
    printf '%s' "$candidate"
}

maybe_rename_path() {
    # Rename the given path by sanitizing ONLY its basename. Returns final path on stdout.
    local old_path="$1"
    local parent
    parent=$(dirname -- "$old_path")
    local base
    base=$(basename -- "$old_path")

    # Exclusion check is against the basename only
    for excluded in "${excluded_files[@]}"; do
        if [[ $base =~ $excluded ]]; then
            printf '%s' "$old_path"
            return 0
        fi
    done

    local sanitized
    sanitized=$(sanitize_basename "$base")

    # Nothing to do
    if [ "$sanitized" = "$base" ]; then
        printf '%s' "$old_path"
        return 0
    fi

    # Avoid collisions inside the same directory
    local target_base
    target_base=$(ensure_unique_target "$parent" "$sanitized")
    local new_path="$parent/$target_base"

    if mv -T -- "$old_path" "$new_path"; then
        printf '%s' "$new_path"
    else
        # If mv fails, output the original path
        printf '%s' "$old_path"
    fi
}

find_files() {
    local dir="$1"
    local include_hidden="$2"
    local find_args=("$dir" -mindepth 1 -maxdepth 1 -print0)

    if [ "$include_hidden" != true ]; then
        # Exclude dotfiles and dotdirs at this depth
        find_args=("$dir" -mindepth 1 -maxdepth 1 -not -name '.*' -print0)
    fi

    # Iterate immediate children; rename, then recurse into directories using their new path
    find "${find_args[@]}" | while IFS= read -r -d $'\0' entry; do
        local new_entry
        new_entry=$(maybe_rename_path "$entry")
        if [ -d "$new_entry" ]; then
            find_files "$new_entry" "$include_hidden"
        fi
    done
}

main() {
    local include_hidden=false
    # Use a global array so called functions can see it (Bash dynamic scoping); default exclude README.md
    excluded_files=("README.md")

    while getopts ":ae:" opt; do
        case $opt in
            a)
                include_hidden=true
                ;;
            e)
                IFS=',' read -r -a excluded_files <<< "$OPTARG"
                ;;
            \?)
                echo "Invalid option: -$OPTARG" >&2
                exit 1
                ;;
        esac
    done
    shift $((OPTIND - 1))

    if [ $# -eq 0 ]; then
        echo "Usage: $0 [-a] [-e <file1,file2,...>] <directory>"
        exit 1
    fi

    local path="$1"

    if [ -d "$path" ]; then
        # Do not rename the root itself; process its children and recurse, renaming as we go
        find_files "$path" "$include_hidden"
    elif [ -f "$path" ]; then
        # Single file rename
        maybe_rename_path "$path" >/dev/null
    else
        echo "$path is not a valid path!"
        exit 1
    fi
}

main "$@"

