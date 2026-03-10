#!/usr/bin/env bash

# Script Name: arith_mean.sh
# Description: Calculate the arithmetic mean of the given numbers.
# Usage: arith_mean.sh list_of_numbers
#        list_of_numbers - A space-separated list of numbers
# Example: ./arith_mean.sh 1 2 3 4 5

# Function: Calculates the mean of a list of numbers
mean() {
    local sum=0.0
    local count=0

    # Loop over all arguments
    for num in "$@"; do
        sum=$(echo "$sum + $num" | bc -l)
        count=$((count + 1))
    done

    # Calculate and print mean with scale of 2 decimal places
    echo "scale=2; $sum / $count" | bc -l
}

# Function: Main function to control the flow of the script
main() {
    # Check if at least one argument is given
    if [ $# -eq 0 ]; then
        echo "Error: No arguments provided."
        echo "Usage: arith_mean.sh list_of_numbers"
        echo "       list_of_numbers - A space-separated list of numbers"
        echo "Example: ./arith_mean.sh 1 2 3 4 5"
        exit 1
    fi

    # Check if each argument is a valid number
    for i in "$@"; do
        if ! [[ $i =~ ^-?[0-9]+([.][0-9]+)?$ ]]; then
            echo "Error: $i is not a number"
            exit 1
        fi
    done

    # Call the mean function and print the result
    echo "Arithmetic mean of $* is $(mean "$@")"
}

main "$@"

