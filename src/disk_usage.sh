#!/usr/bin/env bash

# Script Name: disk_usage.sh
# Description: Finds total disk usage on the machine.
# Usage: disk_usage.sh
# Example: ./disk_usage.sh


# TODO: add option to supply a list of disk name patterns

main() {

    # get file system names and percentage of use
    result=$(df -h | grep sda | awk '{ print $1 " " $5 }' | cut -d'%' -f1)

    echo -e "$result"

}

main "$@"

