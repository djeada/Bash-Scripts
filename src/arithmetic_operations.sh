#!/usr/bin/env bash

# Script Name: arithmetic_operations.sh
# Description: A calculator for arithmetic operations. This script evaluates a mathematical expression provided by the user.
# Usage: arithmetic_operations.sh expression
#        expression - A mathematical expression with the operators: +, -, *, /, %, ^. Parentheses for grouping are also supported.
#        Expressions containing % are evaluated with integer arithmetic (bc scale=0),
#        because bc's % only yields a true remainder at scale 0.
# Example: ./arithmetic_operations.sh "(2+2)*3/2^2"

# Function: Evaluates the arithmetic expression and prints the result with 3 decimal precision
calculate() {
    local expression="$1"
    local scale=5
    local result

    if [[ "$expression" == *%* ]]; then
        scale=0
    fi

    result=$(echo "scale=$scale; $expression" | BC_LINE_LENGTH=0 bc -l 2>&1)

    if ! [[ "$result" =~ ^-?[0-9]*\.?[0-9]+$ ]]; then
        echo "Error: could not evaluate '$expression': ${result:-no result}" >&2
        exit 1
    fi

    LC_ALL=C awk -v value="$result" 'BEGIN { printf "%.3f\n", value }'
}

# Function: Main function to control the flow of the script
main() {
    # Check if exactly one argument is given
    if [ $# -ne 1 ]; then
        echo "Error: Invalid number of arguments." >&2
        echo "Usage: arithmetic_operations.sh expression" >&2
        echo "       expression - A mathematical expression with the operators: +, -, *, /, %, ^. Parentheses for grouping are also supported." >&2
        echo "Example: ./arithmetic_operations.sh \"(2+2)*3/2^2\"" >&2
        exit 1
    fi

    if ! command -v bc &> /dev/null; then
        echo "Error: bc is required but it's not installed. Aborting." >&2
        exit 1
    fi

    # Call the calculate function and print the result
    calculate "$1"
}

main "$@"

