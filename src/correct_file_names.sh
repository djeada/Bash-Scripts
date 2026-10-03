#!/usr/bin/env bash

# Script Name: correct_file_names.sh
# Description: This script recursively corrects file and directory names in a specified directory by replacing
#              all non-alphanumeric characters (excluding dots and underscores) with underscores, converting
#              repeated underscores to a single underscore, trimming leading/trailing underscores and making
#              the names lowercase. If the new name is taken, a numeric suffix (_1, _2, ...) is added.
#              Additionally, it provides an option to include hidden files and directories.
# Usage: correct_file_names.sh [-a] [-e <file1,file2,...>] <directory|file>
#        -a: Include hidden files and directories (default is false).
#        -e: Comma-separated list of exact file/directory names (not paths) to exclude
#            from modification (default is 'README.md').
#        <directory|file>: The directory containing the files to be corrected, or a single file.
# Example: ./correct_file_names.sh -a -e README.md,LICENSE path/to/directory

sanitize_basename() {
    # Transform only a basename (no path separators) according to the rules
    # - replace non-alnum except dot and underscore with underscore
    # - squeeze consecutive underscores
    # - lowercase
    # - trim leading/trailing underscores
    # LC_ALL=C: treat every non-ASCII byte as "non-alphanumeric"
    local name
    name=$(printf '%s' "$1" | LC_ALL=C sed -e 's/[^a-zA-Z0-9._]/_/g')
    name=$(printf '%s' "$name" | LC_ALL=C tr -s '_' | LC_ALL=C tr '[:upper:]' '[:lower:]')
    name=${name#_}
    printf '%s' "${name%_}"
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

    # Exclusion check is an exact match against the basename only
    for excluded in "${excluded_files[@]}"; do
        if [[ $base == "$excluded" ]]; then
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

    # Names made only of special characters would end up empty (or just dots)
    if [[ -z "${sanitized//./}" ]]; then
        echo "Skipping '$old_path': no usable characters in its name." >&2
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

    # Collect the immediate children first (so renaming can't disturb the listing),
    # then rename each one and recurse into directories using their new path
    local -a entries=()
    local entry
    while IFS= read -r -d '' entry; do
        entries+=("$entry")
    done < <(find "${find_args[@]}")

    for entry in "${entries[@]}"; do
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
            ":")
                echo "Option -$OPTARG requires an argument." >&2
                exit 1
                ;;
            "?")
                echo "Invalid option: -$OPTARG" >&2
                exit 1
                ;;
        esac
    done
    shift $((OPTIND - 1))

    if [ $# -eq 0 ]; then
        echo "Usage: $0 [-a] [-e <file1,file2,...>] <directory|file>" >&2
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
        echo "$path is not a valid path!" >&2
        exit 1
    fi
}

main "$@"

