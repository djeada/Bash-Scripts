#!/usr/bin/env bash

# Script Name: arithmetic_operations.sh
# Description: A calculator for arithmetic operations. This script evaluates a mathematical expression provided by the user.
# Usage: arithmetic_operations.sh expression
#        expression - A mathematical expression with the operators: +, -, *, /, %, ^. Parentheses for grouping are also supported.
# Example: ./arithmetic_operations.sh "(2+2)*3/2^2"

# Function: Evaluates the arithmetic expression and prints the result with 3 decimal precision
calculate() {
    # check if bc is installed
    if ! command -v bc &> /dev/null
    then
        echo "bc is required but it's not installed. Aborting."
        exit 1
    fi

    echo "scale=5; $1" | bc -l | awk '{printf "%.3f\n", $1}'
}

# Function: Main function to control the flow of the script
main() {
    # Check if exactly one argument is given
    if [ $# -ne 1 ]; then
        echo "Error: Invalid number of arguments."
        echo "Usage: arithmetic_operations.sh expression"
        echo "       expression - A mathematical expression with the operators: +, -, *, /, %, ^. Parentheses for grouping are also supported."
        echo "Example: ./arithmetic_operations.sh \"(2+2)*3/2^2\""
        exit 1
    fi

    # Call the calculate function and print the result
    calculate "$1"
}

main "$@"

