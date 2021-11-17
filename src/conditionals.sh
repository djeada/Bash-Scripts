#!/usr/bin/env bash

# Script Name: conditionals.sh
# Description: Demonstrates the use of the if statement.
# Usage: conditionals.sh
# Example: ./conditionals.sh

echo "Type a y or n."
read input

if [ "$input"  == "n" ] || [ "$input" == "N" ]; then
    echo "NO"
elif [ "$input"  == "y" ] || [ "$input" == "Y" ]; then
    echo "YES"
fi
