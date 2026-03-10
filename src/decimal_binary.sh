#!/usr/bin/env bash

# Script Name: decimal_binary
# Description: Converts decimal numbers to their binary representation and vice versa.
# Usage: DecimalBinaryConverter.sh [-d2b|-b2d] [number]
#        [-d2b|-b2d] - Flag to specify the conversion direction (-d2b for decimal to binary, -b2d for binary to decimal).
#        [number] - The number to be converted.
# Example: ./decimal_binary.sh -d2b 123
#          ./decimal_binary.sh -b2d 1111011

# Print usage function
print_usage() {
    echo "Usage: $0 [-d2b|-b2b] [number]"
    echo "Converts decimal numbers to their binary representation and vice versa."
}

# Validation of input function
validate_input() {
    re='^[0-9]+$'
    if ! [[ $1 =~ $re ]]; then
        echo "Error: Input is not a positive integer!"
        exit 1
    fi
}

# Conversion of decimal to binary function
decimal_to_binary() {
    local number=$1
    local remainder
    local binary_representation=""

    while [ "$number" -gt 0 ]
    do
        remainder=$(( number % 2))
        binary_representation="$remainder$binary_representation"
        number=$(( number / 2))
    done

    echo "$binary_representation"
}

# Conversion of binary to decimal function
binary_to_decimal() {
    local binary=$1
    echo "$((2#$binary))"
}

# Main function
main() {
    if [ $# -ne 2 ]; then
        echo "Error: Must provide exactly two arguments!"
        print_usage
        exit 1
    fi

    local operation=$1
    local number=$2

    validate_input "$number"

    if [ "$operation" == "-d2b" ]; then
        echo "Conversion of decimal number $number to binary:"
        decimal_to_binary "$number"
    elif [ "$operation" == "-b2d" ]; then
        echo "Conversion of binary number $number to decimal:"
        binary_to_decimal "$number"
    else
        echo "Error: Invalid operation $operation!"
        print_usage
        exit 1
    fi
}

main "$@"

