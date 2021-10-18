#!/usr/bin/env bash

echo "Type a y or n."
read input

if [ "$input"  == "n" ] || [ "$input" == "N" ]; then
    echo "NO"
elif [ "$input"  == "y" ] || [ "$input" == "Y" ]; then
    echo "YES"
fi
