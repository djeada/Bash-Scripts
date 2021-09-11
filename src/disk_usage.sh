#!/usr/bin/env bash

main() {

    # get file system names and percentage of use
    result=$(df -h | grep sda | awk '{ print $1 " " $5 }' | cut -d'%' -f1)

    echo -e "$result"

}

main "$@"
