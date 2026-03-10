#!/usr/bin/env bash

# Script Name: sum_args.sh
# Description: Sums up all arguments passed to the script.
# Usage: sum_args.sh arg1 arg2 ...
#        arg1 arg2 ... - the arguments to sum up.
# Example: ./sum_args.sh 1 2 3 4 5

print_arguments() {
    echo "Arguments submitted:"

    for arg; do
        echo "$arg"
    done
}

calculate_sum() {
    local sum=0

    # Iterate over all the arguments
    for arg; do
        sum=$((sum + arg))
    done

    echo "$sum"
}

main() {
    print_arguments "$@"

    local sum=0
    sum=$(calculate_sum "$@")

    echo "Sum of the arguments: $sum"
}

main "$@"

