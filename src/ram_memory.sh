#!/usr/bin/env bash

# A value in kB
MINIMUM=100000000
MIN_READABLE=$(echo "scale=2; $a/1024/1024" | bc -l)

main() {

    ram="$(free | awk '/^Mem:/{print $2}')"
    if [ $ram -lt $MINIMUM ]; then
        echo "The system doesn't meet the requirements. Memory must be at least $MIN_READABLE GB."
        exit 1
    fi

}

main "$@"
