#!/usr/bin/env bash

# Script Name: find_dead_code.sh
# Description: This script searches for function and class definitions in Python files in the current directory and all subdirectories, and counts their occurrences. It then displays a list of functions and classes that occur less than a specified number of times, which may indicate dead code.
# Usage: `find_dead_code.sh [n]`
# Example: `find_dead_code.sh 3` displays a list of functions and classes that occur less than 3 times in the Python files in the current directory and all subdirectories.

# Set default value for n if no argument is provided
n="${1:-3}"

# Find all .py files in the current directory and all subdirectories
files=$(find . -name '*.py')

# Initialize an empty array to store the names of functions and classes
names=()

# Extract the names of functions and classes from the .py files
for file in $files; do
    while IFS= read -r line; do
        # Check if the line starts with "def" or "class"
        if [[ "$line" == def* ]] || [[ "$line" == class* ]]; then
            # Extract the first word after "def" or "class"
            name=$(echo "$line" | awk '{print $2}' | awk -F '[: (]' '{print $1}')
            # Add the name to the array
            names+=("$name")
        fi
    done < "$file"
done

# Initialize an empty array to store the counts of functions and classes
counts=()

# Count the occurrences of each name in the .py files
for name in "${names[@]}"; do
    count=$(grep -c "$name" $files)
    counts+=("$count")
done

# Display the names and counts of functions and classes that occur less than n times
for i in "${!names[@]}"; do
    if [ "${counts[$i]}" -lt "$n" ]; then
        echo "${names[$i]} occurred ${counts[$i]} times"
    fi
done
