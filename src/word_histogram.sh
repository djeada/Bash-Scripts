#!/bin/bash

# Function to remove diacritics
remove_diacritics()
{
    sed -i 'y/ąāáǎàćēéěèęīíǐìłńōóǒòóśūúǔùǖǘǚǜżźĄĀÁǍÀĆĒĘÉĚÈĪÍǏÌŁŃŌÓǑÒÓŚŪÚǓÙǕǗǙǛŻŹ/aaaaaceeeeeiiiilnooooosuuuuuuuuzzAAAAACEEEEEIIIILNOOOOOSUUUUUUUUZZ/' "$1"
}

# Process text to calculate word frequencies
process_text() {
    local file=$1
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
    done < "$file"

    # Output word frequencies
    for word in "${!wordcounts[@]}"; do
        echo "$word:${wordcounts[$word]}"
    done
}

export -f remove_diacritics process_text

# Main program starts here
min_word_length=0
output_json=false

while getopts ":l:j" opt; do
    case $opt in
        l)
            min_word_length=$OPTARG
            ;;
        j)
            output_json=true
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

if [ "$#" -eq 0 ]; then
    # No files provided, reading from stdin
    if $output_json; then
        process_text "/dev/stdin" "$min_word_length" | jq -Rn '[inputs | split(":") | {(.[0]): .[1]|tonumber}] | add'
    else
        process_text "/dev/stdin" "$min_word_length"
    fi
else
    # Process files in parallel
    parallel --will-cite process_text {} $min_word_length ::: "$@" | sort -rn -t":" -k2 |
    if $output_json; then
        jq -Rn '[inputs | split(":") | {(.[0]): .[1]|tonumber}] | add'
    else
        cat
    fi
fi

