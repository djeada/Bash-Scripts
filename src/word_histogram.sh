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
# Define the temporary file
temp_file=$(mktemp)

# Check if files are provided
if [ "$#" -eq 0 ]; then
    # No files provided, reading from stdin
    input="/dev/stdin"
    if $output_json; then
        process_text "$input" "$min_word_length" > "$temp_file"
        jq -Rn '[inputs | split(":") | {(.[0]): (. [1] | tonumber)}] | add' < "$temp_file"
    else
        process_text "$input" "$min_word_length"
    fi
else
    # Process files in parallel
    export min_word_length
    export output_json
    if $output_json; then
        parallel --will-cite "process_text {} $min_word_length" ::: "$@" > "$temp_file"
        jq -Rn '[inputs | split(":") | {(.[0]): (. [1] | tonumber)}] | add' < "$temp_file"
    else
        parallel --will-cite "process_text {} $min_word_length" ::: "$@" > "$temp_file"
        cat "$temp_file" | sort -t: -k2,2nr
    fi
fi

# Clean up the temporary file
rm "$temp_file"

