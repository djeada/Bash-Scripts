#!/usr/bin/env bash

main() {

    if [ $# -ne 1 ]; then
        echo "You must provide an expression to be evaluated!"
        exit 1
    fi

    echo "scale=5; $1" | bc -l | awk '{printf "%.3f\n", $1}'
}

main "$@"
