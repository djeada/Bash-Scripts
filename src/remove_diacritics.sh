#!/usr/bin/env bash

# Script Name: remove_diacritics.sh
# Description: Removes the diacritics from all the files in a given directory.
# Usage: remove_diacritics.sh [<directory_path>]
#        [<directory_path>] - the path to the directory to process.
# Example: ./remove_diacritics.sh path/to/directory

remove_diacritics ()
{
    sed -i 'y/ąāáǎàćēéěèęīíǐìłńōóǒòóśūúǔùǖǘǚǜżźĄĀÁǍÀĆĒĘÉĚÈĪÍǏÌŁŃŌÓǑÒÓŚŪÚǓÙǕǗǙǛŻŹ/aaaaaceeeeeiiiilnooooosuuuuuuuuzzAAAAACEEEEEIIIILNOOOOOSUUUUUUUUZZ/' "$1"
}

main() {

    if [ $# -eq 0 ]; then
        echo "Must provide a path!"
        exit 1
    fi

    if [ "$1" == '.' ] || [ -d "${1}" ]; then
        find "$1" -maxdepth 10 -type f -print0 | while IFS= read -r -d '' file; do
            remove_diacritics "$file"
        done
    elif [ -f "${1}" ]; then
        remove_diacritics "$1"
    else
        echo "$1 is not a valid path!"
    fi

}

main "$@"

