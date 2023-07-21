#!/usr/bin/env bash

# Script Name: ip_info.sh
# Description: Retrieves and displays information about IP addresses.
# Usage: ip_info.sh [--help] [--public] [--private] [--location]
#        --help - Displays help information.
#        --public - Displays the public IP address.
#        --private - Displays the private IP address.
#        --location - Displays location information for the public IP address.

display_usage() {
    cat << EOF
Usage: $0 [--help] [--public] [--private] [--location]

This script retrieves and displays information about IP addresses.

Options:
    --help      Display this help and exit.
    --public    Display the public IP address.
    --private   Display the private IP address.
    --location  Display location information for the public IP address.
EOF
}

display_public_ip() {
    public_ip=$(curl -s https://api.ipify.org)
    echo "Public IP: $public_ip"
}

display_private_ip() {
    private_ip=$(hostname -I | awk '{print $1}')
    echo "Private IP: $private_ip"
}

display_location() {
    if [[ -z $public_ip ]]; then
        public_ip=$(curl -s https://api.ipify.org)
    fi
    location_info=$(curl -s http://ip-api.com/json/"$public_ip")
    country=$(echo "$location_info" | grep -Po '"country":.*?[^\\]",' | awk -F':' '{print $2}' | sed 's/","//g' | sed 's/"//g')
    region=$(echo "$location_info" | grep -Po '"regionName":.*?[^\\]",' | awk -F':' '{print $2}' | sed 's/","//g' | sed 's/"//g')
    postal_code=$(echo "$location_info" | grep -Po '"zip":.*?[^\\]",' | awk -F':' '{print $2}' | sed 's/","//g' | sed 's/"//g')
    lat=$(echo "$location_info" | grep -Po '"lat":.*?[^\\],' | awk -F':' '{print $2}' | sed 's/,//g')
    lon=$(echo "$location_info" | grep -Po '"lon":.*?[^\\],' | awk -F':' '{print $2}' | sed 's/,//g')
    echo -e "Location Information:\nCountry: $country\nRegion: $region\nPostal Code: $postal_code\nLatitude: $lat\nLongitude: $lon"
}

main() {
    include_public_ip=true
    include_private_ip=true
    include_location=true

    while (( $# )); do
        case $1 in
            --help)
                display_usage
                exit 0
                ;;
            --public)
                include_private_ip=false
                include_location=false
                ;;
            --private)
                include_public_ip=false
                include_location=false
                ;;
            --location)
                include_public_ip=false
                include_private_ip=false
                ;;
            *)
                echo "Invalid option: $1" >&2
                display_usage >&2
                exit 1
        esac
        shift
    done

    if [[ $include_public_ip == true ]]; then
        display_public_ip
    fi

    if [[ $include_private_ip == true ]]; then
        display_private_ip
    fi

    if [[ $include_location == true ]]; then
        display_location
    fi
}

main "$@"

