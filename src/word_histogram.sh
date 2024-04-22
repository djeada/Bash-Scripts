#!/bin/bash

# Function to remove diacritics
remove_diacritics()
{
    sed -i 'y/ąāáǎàćēéěèęīíǐìłńōóǒòóśūúǔùǖǘǚǜżźĄĀÁǍÀĆĒĘÉĚÈĪÍǏÌŁŃŌÓǑÒÓŚŪÚǓÙǕǗǙǛŻŹ/aaaaaceeeeeiiiilnooooosuuuuuuuuzzAAAAACEEEEEIIIILNOOOOOSUUUUUUUUZZ/' "$1"
}

# Process text to calculate word frequencies
process_text() {
    local min_word_length=$2
    declare -A wordcounts

    while read -r line; do
        line=$(remove_diacritics "$line")
        line=$(echo "$line" | tr -dc '[:alpha:][:space:]')

        for word in $line; do
            word=${word,,}  # Convert to lowercase
            if [ ${#word} -ge "$min_word_length" ]; then
                ((wordcounts[$word]++))
            fi
        done
    done

    # Print word frequencies
    for word in "${!wordcounts[@]}"; do
        echo "$word:${wordcounts[$word]}"
    done | sort -rn -t":" -k2
}

# Main program starts here
min_word_length=0
file_mode=false

while getopts ":l:" opt; do
    case $opt in
        l)
            min_word_length=$OPTARG
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            exit 1
            ;;
    esac
done
shift $((OPTIND -1))

# Check input method
if [ "$#" -eq 0 ]; then
    # Reading from standard input (pipe or redirection)
    process_text "/dev/stdin" "$min_word_length"
else
    # Reading from files
    for filename in "$@"; do
        if [ -f "$filename" ]; then
            echo "Processing $filename..."
            process_text "$filename" "$min_word_length"
        else
            echo "File $filename not found."
            exit 1
        fi
    done
fi
