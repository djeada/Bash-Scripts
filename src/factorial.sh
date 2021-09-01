#!/usr/bin/env bash

main() {

    if [ $# -ne 1 ]; then
        echo "Must provide exactly one number!"
        exit 1
    fi

    re='^[0-9]+$'
    if ! [[ $1 =~ $re ]]; then
        echo "$1 is not a positive integer!"
        exit 1
    fi

    fact=1
    num=$1

    while [ $num -gt 1 ]
    do
        fact=$((fact * num))  #fact = fact * num
        num=$((num - 1))      #num = num - 1
    done

    echo $fact
}

main "$@"
