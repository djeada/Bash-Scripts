#!/usr/bin/env bash

main() {
    if [ $# -eq 0 ]; then
        echo "You must provide a path!"
        exit 1
    fi

    if [ ! -f $1 ]; then
        echo "$1 is not a valid path!"
        exit 1
    fi

    middle=$(($(sed -n '$=' $1)/2))
    head -$middle $1 | tail -n +$middle
}

main "$@"
