#!/usr/bin/env bash

# Script Name: word_histogram.sh
# Description: Generates a word frequency histogram from text files (or standard input).
#              Words are lowercased, common diacritics are removed (ą -> a, ...) and
#              non-letter characters are dropped. Counts from all files are combined
#              and printed as "word:count", most frequent first.
# Usage: ./word_histogram.sh [-l min_word_length] [-n top_n] [-j] [file ...]
#        -l N  Only count words with at least N letters (default: 1).
#        -n N  Only print the N most frequent words (default: all).
#        -j    Output a JSON object instead (requires jq).
# Example: ./word_histogram.sh -l 3 -n 20 document.txt

usage() {
    echo "Usage: $0 [-l min_word_length] [-n top_n] [-j] [file ...]" >&2
}

# Remove diacritics from the input text
remove_diacritics() {
    sed 'y/ąāáǎàćēéěèęīíǐìłńōóǒòóśūúǔùǖǘǚǜżźĄĀÁǍÀĆĒĘÉĚÈĪÍǏÌŁŃŌÓǑÒÓŚŪÚǓÙǕǗǙǛŻŹ/aaaaaceeeeeiiiilnooooosuuuuuuuuzzAAAAACEEEEEIIIILNOOOOOSUUUUUUUUZZ/'
}

# Print "word:count" lines for the text on stdin, most frequent first
count_words() {
    local min_word_length=$1

    remove_diacritics \
        | tr -dc '[:alpha:][:space:]' \
        | tr -s '[:space:]' '\n' \
        | tr '[:upper:]' '[:lower:]' \
        | awk -v min="$min_word_length" 'length($0) >= min && length($0) > 0 { c[$0]++ } END { for (w in c) print w ":" c[w] }' \
        | sort -t: -k2,2nr -k1,1
}

# Keep only the first top_n lines (all lines if top_n is 0)
limit_output() {
    if (( top_n > 0 )); then
        head -n "$top_n"
    else
        cat
    fi
}

# Print "word:count" lines as-is, or as a JSON object with -j
format_output() {
    if $output_json; then
        jq -Rn '[inputs | split(":") | {(.[0]): (.[1] | tonumber)}] | add // {}'
    else
        cat
    fi
}

min_word_length=1
top_n=0
output_json=false

while getopts ":l:n:j" opt; do
    case $opt in
        l)
            min_word_length=$OPTARG
            ;;
        n)
            top_n=$OPTARG
            ;;
        j)
            output_json=true
            ;;
        ":")
            echo "Option -$OPTARG requires an argument." >&2
            usage
            exit 1
            ;;
        *)
            echo "Invalid option: -$OPTARG" >&2
            usage
            exit 1
            ;;
    esac
done
shift $((OPTIND - 1))

if ! [[ $min_word_length =~ ^[0-9]+$ && $top_n =~ ^[0-9]+$ ]]; then
    echo "Error: -l and -n require non-negative integers." >&2
    exit 1
fi

if $output_json && ! command -v jq &> /dev/null; then
    echo "Error: jq is required for JSON output (-j)." >&2
    exit 1
fi

for file in "$@"; do
    if [[ ! -f $file || ! -r $file ]]; then
        echo "Error: cannot read file: $file" >&2
        exit 1
    fi
done

# With no files, cat reads standard input
cat -- "$@" | count_words "$min_word_length" | limit_output | format_output

