#!/usr/bin/env bash

# Script Name: remove_diacritics.sh
# Description: Removes the diacritics from all the files in a given directory.
# Usage: remove_diacritics.sh [<directory_path>]
#        [<directory_path>] - the path to the directory to process.
# Example: ./remove_diacritics.sh path/to/directory

remove_diactrics ()
{
    sed -i 'y/ąāáǎàćēéěèęīíǐìłńōóǒòóśūúǔùǖǘǚǜżźĄĀÁǍÀĆĒĘÉĚÈĪÍǏÌŁŃŌÓǑÒÓŚŪÚǓÙǕǗǙǛŻŹ/aaaaaceeeeeiiiilnooooosuuuuüüüüzzAAAAACEEEEEIIIILNOOOOOSUUUUÜÜÜÜZZ/' $1
}

main() {

    if [ $# -eq 0 ]; then
        echo "Must provide a path!"
        exit 1
    fi

    if [ $1 == '.' ] || [ -d "${1}" ]; then
        for file in $(find $1 -maxdepth 10 -type f)
        do
            remove_diactrics $file
        done
    elif [ -f "${1}" ]; then
        remove_diactrics $1
    else
        echo "$1 is not a valid path!"
    fi

}

main "$@"
