#!/usr/bin/env bash

# Script Name: ip_info.sh
# Description: Displays information about the IP address.
# Usage: ip_info.sh [<h>] [<public>] [<private>] [<location>]
#        [<h>] - displays help
#        [<public>] - displays public IP address
#        [<private>] - displays private IP address
#        [<location>] - displays location of the IP address
# Example: ./ip_info.sh public private location

help() {
    echo "NAME"
    echo "ip_info.sh - displays information about the IP address"
    echo
    echo "SYNTAX"
    echo "ip_info.sh [h] [public] [private] [locate]"
    echo
    echo "OPTIONS"
    echo "h - displays this help"
    echo "public - displays the public IP address"
    echo "private - displays the private IP address"
    echo "locate - displays the location of the IP address"
}

display_public_ip() {
    if [ -n "$include_public_ip" ]; then
        public_ip=$(dig +short myip.opendns.com @resolver1.opendns.com)
        echo "Public ip: $public_ip"
    fi
}

display_private_ip() {
    if [ -n "$include_private_ip" ]; then
        private_ip=$(ip route get 1 | awk '{print $(NF-2);exit}')
        echo "Private ip: $private_ip"
    fi
}

get_value_from_dict() {
    dict=$1
    key=$2
    echo "$dict" | grep -m1 -oP '"'"$key"'"?\s*:\s*"?\K[^"]+'
}

display_location() {
    if [ -n "$include_location" ]; then

        if [ -n "$public_ip" ]; then
            public_ip=$(dig +short myip.opendns.com @resolver1.opendns.com)
        fi

        ip_dict=$(curl http://ip-api.com/json/"$public_ip" 2>&1)
        status=$(get_value_from_dict "$ip_dict" "status")

        if [[ $status == "success" ]]; then
            echo "Country: $(get_value_from_dict "$ip_dict" "country")"
            echo "Region: $(get_value_from_dict "$ip_dict" "regionName")"
            echo "Postal code: $(get_value_from_dict "$ip_dict" "zip")"

            lat=$(get_value_from_dict "$ip_dict" "lat")
            lon=$(get_value_from_dict "$ip_dict" "lon")
            echo "Latitude: ${lat::-1}"
            echo "Longitude: ${lon::-1}"
        else
            echo "Couldn't find any informations!"
        fi
    fi
}

parse_arguments() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--h)
                help && exit 1
                ;;
            -public|--public)
                include_public_ip=true
                ;;
            -private|--private)
                include_private_ip=true
                ;;
            -location|--location)
                include_location=true
                ;;
            *)
                echo "$1 is not a valid argument! Use -h to display all valid arguments."
                exit 1
        esac
        shift
    done
}

main() {
    parse_arguments "$@"

    display_public_ip
    display_private_ip
    display_location
}

main "$@"

