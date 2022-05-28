#!/usr/bin/env bash

# Script Name: arithmetic_operations.sh
# Description: A simple arithmetic operations calculator.
# Usage: arithmetic_operations.sh [expression]
#        [expression] is a mathematical expression with the following operators: +, -, *, /, %, ^
# Example: ./arithmetic_operations.sh 2+2

main() {

    if [ $# -ne 1 ]; then
        echo "You must provide an expression to be evaluated!"
        exit 1
    fi

    echo "scale=5; $1" | bc -l | awk '{printf "%.3f\n", $1}'
}

main "$@"

