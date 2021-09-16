#!/usr/bin/env bash

main() {

    if [ $# -eq 0 ]; then
        path="."
    elif [ -d $1 ]; then
        path="$1"
    else
        echo "provided path is not valid!"
        exit 1
    fi

    cd $path
    git ls-files -z | xargs -0 wc -l | awk 'END{print}'
}

main "$@"
