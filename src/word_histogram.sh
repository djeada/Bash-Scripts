#!/bin/bash

# Function to remove diacritics
remove_diacritics()
{
    sed -i 'y/ąāáǎàćēéěèęīíǐìłńōóǒòóśūúǔùǖǘǚǜżźĄĀÁǍÀĆĒĘÉĚÈĪÍǏÌŁŃŌÓǑÒÓŚŪÚǓÙǕǗǙǛŻŹ/aaaaaceeeeeiiiilnooooosuuuuuuuuzzAAAAACEEEEEIIIILNOOOOOSUUUUUUUUZZ/' "$1"
}

# Check if file is given as argument
if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    echo "Usage: $0 filename [min_word_length]"
    exit 1
fi

# Check if file exists
if [ ! -f $1 ]; then
    echo "File $1 not found."
    exit 1
fi

# If second argument is present, set min_word_length
min_word_length=0
if [ ! -z "$2" ]; then
    min_word_length=$2
fi

# Calculate word frequencies
echo "Calculating word frequencies..."
declare -A wordcounts
while read -r line
do
    line=$(remove_diacritics "$line") # remove diacritics
    line=$(echo "$line" | tr -dc '[:alpha:][:space:]') # remove non-letter characters
    for word in $line
    do
        word=${word,,} # convert to lowercase
        if [ ${#word} -ge $min_word_length ]; then
            ((wordcounts[$word]++))
        fi
    done
done < "$1"

# Sort and print word frequencies
echo "Printing sorted word frequencies..."
for word in "${!wordcounts[@]}"; do
    echo "$word:${wordcounts[$word]}"
done | sort -rn -t":" -k2
