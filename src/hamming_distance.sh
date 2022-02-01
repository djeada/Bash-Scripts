#!/usr/bin/env bash

# Script Name: hamming_distance.sh
# Description: Calculate the Hamming Distance of two strings.
# Usage: hamming_distance.sh [string_a] [string_b]
#       [string_a] - one of the strings to compare
#       [string_b] - the other string to compare
# Example: hamming_distance.sh "xxbab" "wokka bbabb"
# Output: 4

odleglosc_hamminga() {

    local string_a="$1"
    local string_b="$2"
    local n=${#string_a}
    local m=${#string_b}

    if [ "$n" -ne "$m" ]; then
        echo "-1"
        return
    fi

    local result=0
    for((i=0;i<n;i++)); do
        if [[ "${string_a:$i:1}" != "${string_b:$i:1}" ]]; then
            local result=$((result+1))
        fi
    done

    echo "$result"

}

main() {

    if [ $# -ne 2 ]; then
        echo "Usage: hamming_distance.sh [string_a] [string_b]"
        return
    fi

    hamming_distance "$1" "$2"
}

main "$@"
