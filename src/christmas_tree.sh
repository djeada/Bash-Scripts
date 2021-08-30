#!/usr/bin/env bash

triangle() {

    a=$1

    for (( i=0; i<$a; i++ )); do
        for (( j=0; j<=$i; j++ )); do
            echo -n "x"
        done
        echo ""
    done

}

christmas_tree() {

    n=$1

    for (( i=1; i<=$n; i++ )); do
        triangle $i
    done

}

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

    christmas_tree $1

}

main "$@"
