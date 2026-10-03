#!/usr/bin/env bash

# Script Name: remove_diacritics.sh
# Description: Removes the diacritics (e.g. ą -> a, Ż -> Z) from a file, or from all text
#              files in a directory (up to 10 levels deep), in place.
#              Binary files and .git directories are skipped. Requires a UTF-8 locale.
# Usage: remove_diacritics.sh <path>
#        <path> - the file or directory to process.
# Example: ./remove_diacritics.sh path/to/directory

FROM='ąāáǎàćēéěèęīíǐìłńōóǒòóśūúǔùǖǘǚǜżźĄĀÁǍÀĆĒĘÉĚÈĪÍǏÌŁŃŌÓǑÒÓŚŪÚǓÙǕǗǙǛŻŹ'
TO='aaaaaceeeeeiiiilnooooosuuuuuuuuzzAAAAACEEEEEIIIILNOOOOOSUUUUUUUUZZ'

remove_diacritics() {
    local file="$1"

    # Skip binary files, and files without any of the characters (avoids needless rewrites)
    grep -Iq . "$file" || return 0
    grep -q "[$FROM]" "$file" || return 0

    sed -i "y/$FROM/$TO/" "$file"
}

main() {
    if [ $# -eq 0 ]; then
        echo "Must provide a path!" >&2
        echo "Usage: remove_diacritics.sh <path>" >&2
        exit 1
    fi

    # sed's y command needs a multibyte-aware locale to treat each accented letter as one character
    if [[ $(locale charmap 2>/dev/null) != "UTF-8" ]]; then
        echo "Error: a UTF-8 locale is required (e.g. LC_ALL=C.UTF-8)." >&2
        exit 1
    fi

    local status=0
    if [ -d "$1" ]; then
        while IFS= read -r -d '' file; do
            remove_diacritics "$file" || status=1
        done < <(find "$1" -maxdepth 10 -name .git -prune -o -type f -print0)
    elif [ -f "$1" ]; then
        remove_diacritics "$1" || status=1
    else
        echo "$1 is not a valid path!" >&2
        exit 1
    fi

    exit "$status"
}

main "$@"

