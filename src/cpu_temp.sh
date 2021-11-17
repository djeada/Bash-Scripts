#!/usr/bin/env bash

# Script Name: cpu_temp.sh
# Description: Displays the current CPU temperature.
# Usage: cpu_temp.sh
# Example: ./cpu_temp.sh

main() {

    if [ $# -eq 1 ]; then
        if [ ! -f $1 ]; then
            echo "$1 is not a valid path!"
            exit 1
        fi
        path=$1

    elif [ $# -gt 1 ]; then
        echo "You can't provide more than one path!"
        exit 1

    else
        path=/sys/class/thermal/thermal_zone0/temp
    fi

    temp=$(cat $path)
    temp=$((temp/1000))

    echo "CPU temp: $temp C"

}

main "$@"
