#!/bin/bash

# Function to remove diacritics from a line of text
remove_diacritics()
{
    echo "$1" | sed 'y/ąāáǎàćēéěèęīíǐìłńōóǒòóśūúǔùǖǘǚǜżźĄĀÁǍÀĆĒĘÉĚÈĪÍǏÌŁŃŌÓǑÒÓŚŪÚǓÙǕǗǙǛŻŹ/aaaaaceeeeeiiiilnooooosuuuuuuuuzzAAAAACEEEEEIIIILNOOOOOSUUUUUUUUZZ/'
}

# Process text to calculate word frequencies
process_text() {
    local file=$1
    local min_word_length=$2
    declare -A wordcounts

    while IFS= read -r line; do
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

# Correct the usage of parallel to ensure file names are treated correctly and outputs are merged
if [ "$#" -eq 0 ]; then
    # No files provided, reading from stdin
    input="/dev/stdin"
    if $output_json; then
        process_text "$input" "$min_word_length" | jq -Rn '[inputs | split(":") | {(.[0]): .[1]|tonumber}] | add'
    else
        process_text "$input" "$min_word_length" | sort -t: -k2,2nr
    fi
else
    # Process files in parallel and merge results
    export min_word_length
    export output_json
    if $output_json; then
        parallel --will-cite 'process_text {} $min_word_length | jq -Rsn "[inputs | split(\":\") | {(.[0]): .[1]|tonumber}]" | add' ::: "$@" | jq -s 'add | to_entries | sort_by(.value) | .[] | "\(.[key]):\(.[value])"' | jq -s 'from_entries'
    else
        parallel --will-cite 'process_text {} $min_word_length' ::: "$@" | sort -t: -k2,2nr
    fi
fi

