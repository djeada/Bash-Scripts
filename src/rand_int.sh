#!/usr/bin/env bash

# Script Name: rand_int.sh
# Description: Generates a random integer within a specific range. 
# Usage: rand_int.sh [<lower_bound>] [<upper_bound>]
#        [<lower_bound>] - the smallest number that could be generated.
#        [<upper_bound>] - the largest number that could be generated.
# Example: ./rand_int.sh 1 10

main() {

    if [ $# -ne 2 ]; then
        echo "Must provide exactly two numbers!"
        exit 1
    fi

    re='^[0-9]+$'
    if ! [[ $1 =~ $re ]]; then
        echo "$1 is not a positive integer!"
        exit 1
    fi
    
    if ! [[ $2 =~ $re ]]; then
        echo "$2 is not a positive integer!"
        exit 1
    fi
    
    lower_bound=$1
    upper_bound=$2

    echo $((lower_bound + SRANDOM % upper_bound))

}

main "$@"
