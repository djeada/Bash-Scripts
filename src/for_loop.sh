#!/usr/bin/env bash

# Script Name: for_loop.sh
# Description: Demonstrates the use of for loop.
# Usage: for_loop.sh
# Example: ./for_loop.sh

echo "Enter a positive number: "
read -r n

echo "Numbers from 1 to $n:"
for (( i=1; i<=n; i++ ))
do
    echo "$i"
done

