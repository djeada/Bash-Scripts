#!/usr/bin/env bash

# Script Name: decimal_binary.sh
# Description: Converts decimal numbers to their binary representation and vice versa.
# Usage: decimal_binary.sh [-d2b|-b2d] [number]
#        [-d2b|-b2d] - Flag to specify the conversion direction (-d2b for decimal to binary, -b2d for binary to decimal).
#        [number] - The number to be converted (non-negative).
# Example: ./decimal_binary.sh -d2b 123
#          ./decimal_binary.sh -b2d 1111011

# Print usage function
print_usage() {
    echo "Usage: $0 [-d2b|-b2d] [number]"
    echo "Converts decimal numbers to their binary representation and vice versa."
}

# Validation of input function: $1 number, $2 allowed-digits regex, $3 label
validate_input() {
    if ! [[ $1 =~ $2 ]]; then
        echo "Error: '$1' is not a valid $3 number!" >&2
        exit 1
    fi
}

# Conversion of decimal to binary function
decimal_to_binary() {
    local number=$((10#$1)) # force base 10 so leading zeros are not read as octal
    local binary_representation=""

    while (( number > 0 )); do
        binary_representation="$(( number % 2 ))$binary_representation"
        number=$(( number / 2 ))
    done

    echo "${binary_representation:-0}"
}

# Conversion of binary to decimal function
binary_to_decimal() {
    echo "$((2#$1))"
}

# Main function
main() {
    if [ $# -ne 2 ]; then
        echo "Error: Must provide exactly two arguments!" >&2
        print_usage >&2
        exit 1
    fi

    local operation=$1
    local number=$2

    if [ "$operation" == "-d2b" ]; then
        validate_input "$number" '^[0-9]+$' decimal
        echo "Conversion of decimal number $number to binary:"
        decimal_to_binary "$number"
    elif [ "$operation" == "-b2d" ]; then
        validate_input "$number" '^[01]+$' binary
        echo "Conversion of binary number $number to decimal:"
        binary_to_decimal "$number"
    else
        echo "Error: Invalid operation $operation!" >&2
        print_usage >&2
        exit 1
    fi
}

main "$@"

