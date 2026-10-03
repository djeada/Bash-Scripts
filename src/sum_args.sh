#!/usr/bin/env bash

# Script Name: sum_args.sh
# Description: Sums up all arguments passed to the script.
# Usage: sum_args.sh arg1 arg2 ...
#        arg1 arg2 ... - the integers to sum up (negative values allowed).
# Example: ./sum_args.sh 1 2 3 4 5

print_arguments() {
    echo "Arguments submitted:"

    for arg; do
        echo "$arg"
    done
}

validate_arguments() {
    for arg; do
        # Only plain integers: anything else would be evaluated as an
        # arithmetic expression (variable names, command substitutions...).
        if ! [[ $arg =~ ^-?[0-9]+$ ]]; then
            echo "Error: '$arg' is not an integer." >&2
            exit 1
        fi
    done
}

calculate_sum() {
    local sum=0

    # Iterate over all the arguments (10# avoids octal parsing of e.g. 08)
    for arg; do
        if [[ $arg == -* ]]; then
            sum=$((sum - 10#${arg#-}))
        else
            sum=$((sum + 10#$arg))
        fi
    done

    echo "$sum"
}

main() {
    validate_arguments "$@"
    print_arguments "$@"

    local sum=0
    sum=$(calculate_sum "$@")

    echo "Sum of the arguments: $sum"
}

main "$@"

