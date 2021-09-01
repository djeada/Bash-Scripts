#!/usr/bin/env bash

help() {
    echo "               ip info"
    echo
    echo "Syntax: ip_info [-h|public|private|locate]"
    echo "options:"
    echo "h          Print this Help."
    echo "public     Print public ip address."
    echo "private    Print private ip address."
    echo "locate     Print location based on public ip address."
    echo
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
    echo $dict | grep -m1 -oP '"'"$key"'"?\s*:\s*"?\K[^"]+'
}

display_location() {
    if [ -n "$include_location" ]; then

        if [ -n "$public_ip" ]; then
            public_ip=$(dig +short myip.opendns.com @resolver1.opendns.com)
        fi

        ip_dict=$(curl http://ip-api.com/json/$public_ip 2>&1)
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
