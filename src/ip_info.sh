#!/usr/bin/env bash

# Script Name: ip_info.sh
# Description: Retrieves and displays information about IP addresses and network interfaces.
# Usage: ip_info.sh [options]
#
# Options:
#   -h, --help            Display this help and exit.
#   -V, --version         Display version information and exit.
#   -p, --public          Display the public IP address.
#   -l, --location        Display location information for the public IP address.
#   -r, --private         Display private IP addresses.
#   -i, --interface IFACE Display IP address of a specific network interface.
#   -a, --all             Display all available information.
#   -j, --json            Output in JSON format.
#   -s, --save FILE       Save output to a file.
#   -v, --verbose         Enable verbose output.
#
# Examples:
#   ip_info.sh --public
#   ip_info.sh --private
#   ip_info.sh --location
#   ip_info.sh --interface eth0
#   ip_info.sh --all
#   ip_info.sh --json
#
# Dependencies:
#   - curl
#   - jq (optional, for JSON parsing)


set -euo pipefail

# Default configurations
include_public_ip=false
include_private_ip=false
include_location=false
interface=""
output_json=false
save_file=""
verbose=false
version="1.0.0"

# Check for required dependencies
if ! command -v curl >/dev/null 2>&1; then
    echo "Error: 'curl' is required but not installed." >&2
    exit 1
fi

# Check if 'jq' is available
if command -v jq >/dev/null 2>&1; then
    jq_available=true
else
    jq_available=false
fi

# Variables to store IP addresses
public_ip=""
private_ip=""

display_usage() {
    cat << EOF
Usage: $0 [options]

This script retrieves and displays information about IP addresses and network interfaces.

Options:
  -h, --help            Display this help and exit.
  -V, --version         Display version information and exit.
  -p, --public          Display the public IP address.
  -l, --location        Display location information for the public IP address.
  -r, --private         Display private IP addresses.
  -i, --interface IFACE Display IP address of a specific network interface.
  -a, --all             Display all available information.
  -j, --json            Output in JSON format.
  -s, --save FILE       Save output to a file.
  -v, --verbose         Enable verbose output.

Examples:
  $0 --public
  $0 --private
  $0 --location
  $0 --interface eth0
  $0 --all
  $0 --json

Dependencies:
  - curl
  - jq (optional, for JSON parsing)
EOF
}

display_version() {
    echo "$0 version $version"
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -h|--help)
            display_usage
            exit 0
            ;;
        -V|--version)
            display_version
            exit 0
            ;;
        -p|--public)
            include_public_ip=true
            shift
            ;;
        -l|--location)
            include_location=true
            shift
            ;;
        -r|--private)
            include_private_ip=true
            shift
            ;;
        -i|--interface)
            if [[ -n "${2-}" ]]; then
                interface="$2"
                shift 2
            else
                echo "Error: --interface requires a non-empty argument." >&2
                exit 1
            fi
            ;;
        -a|--all)
            include_public_ip=true
            include_private_ip=true
            include_location=true
            shift
            ;;
        -j|--json)
            output_json=true
            shift
            ;;
        -s|--save)
            if [[ -n "${2-}" ]]; then
                save_file="$2"
                shift 2
            else
                echo "Error: --save requires a file path." >&2
                exit 1
            fi
            ;;
        -v|--verbose)
            verbose=true
            shift
            ;;
        *)
            echo "Invalid option: $1" >&2
            display_usage >&2
            exit 1
            ;;
    esac
done

# If no options are specified, default to displaying all information
if [[ "$include_public_ip" == false && "$include_private_ip" == false && "$include_location" == false && -z "$interface" ]]; then
    include_public_ip=true
    include_private_ip=true
    include_location=true
fi

display_public_ip() {
    if [[ -z "$public_ip" ]]; then
        public_ip=$(curl -s https://api.ipify.org)
        if [[ -z "$public_ip" ]]; then
            echo "Error: Unable to retrieve public IP address." >&2
            exit 1
        fi
    fi
    if [[ "$output_json" == true ]]; then
        echo "{\"public_ip\": \"$public_ip\"}"
    else
        echo "Public IP: $public_ip"
    fi
}

display_private_ip() {
    if [[ -n "$interface" ]]; then
        # Get IP address of specified interface
        if [[ "$(uname)" == "Darwin" ]]; then
            private_ip=$(ifconfig "$interface" 2>/dev/null | awk '/inet /{print $2}')
        else
            private_ip=$(ip addr show "$interface" 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1)
        fi
        if [[ -z "$private_ip" ]]; then
            echo "Error: Unable to retrieve IP address for interface '$interface'." >&2
            exit 1
        fi
        if [[ "$output_json" == true ]]; then
            echo "{\"interface\": \"$interface\", \"private_ip\": \"$private_ip\"}"
        else
            echo "Interface '$interface' IP: $private_ip"
        fi
    else
        # Get all private IP addresses
        if [[ "$(uname)" == "Darwin" ]]; then
            private_ips=$(ifconfig | awk '/inet /{print $2}' | grep -v '127.0.0.1')
        else
            private_ips=$(hostname -I)
        fi
        if [[ "$output_json" == true ]]; then
            ips_array=$(echo "$private_ips" | tr ' ' '\n' | jq -R . | jq -s .)
            echo "{\"private_ips\": $ips_array}"
        else
            echo "Private IPs:"
            echo "$private_ips"
        fi
    fi
}

display_location() {
    if [[ -z "$public_ip" ]]; then
        display_public_ip >/dev/null
    fi
    location_info=$(curl -s http://ip-api.com/json/"$public_ip")
    if [[ "$output_json" == true ]]; then
        echo "$location_info"
    else
        if [[ "$jq_available" == true ]]; then
            status=$(echo "$location_info" | jq -r '.status')
            if [[ "$status" != "success" ]]; then
                message=$(echo "$location_info" | jq -r '.message')
                echo "Error retrieving location information: $message" >&2
                exit 1
            fi
            country=$(echo "$location_info" | jq -r '.country')
            region=$(echo "$location_info" | jq -r '.regionName')
            city=$(echo "$location_info" | jq -r '.city')
            zip=$(echo "$location_info" | jq -r '.zip')
            lat=$(echo "$location_info" | jq -r '.lat')
            lon=$(echo "$location_info" | jq -r '.lon')
            isp=$(echo "$location_info" | jq -r '.isp')
        else
            # Parse using grep and sed
            status=$(echo "$location_info" | grep -Po '"status":.*?[^\\]",' | awk -F':' '{print $2}' | sed 's/[",]//g')
            if [[ "$status" != "success" ]]; then
                message=$(echo "$location_info" | grep -Po '"message":.*?[^\\]",' | awk -F':' '{print $2}' | sed 's/[",]//g')
                echo "Error retrieving location information: $message" >&2
                exit 1
            fi
            country=$(echo "$location_info" | grep -Po '"country":.*?[^\\]",' | awk -F':' '{print $2}' | sed 's/[",]//g')
            region=$(echo "$location_info" | grep -Po '"regionName":.*?[^\\]",' | awk -F':' '{print $2}' | sed 's/[",]//g')
            city=$(echo "$location_info" | grep -Po '"city":.*?[^\\]",' | awk -F':' '{print $2}' | sed 's/[",]//g')
            zip=$(echo "$location_info" | grep -Po '"zip":.*?[^\\]",' | awk -F':' '{print $2}' | sed 's/[",]//g')
            lat=$(echo "$location_info" | grep -Po '"lat":.*?[^\\],' | awk -F':' '{print $2}' | sed 's/,//g')
            lon=$(echo "$location_info" | grep -Po '"lon":.*?[^\\],' | awk -F':' '{print $2}' | sed 's/,//g')
            isp=$(echo "$location_info" | grep -Po '"isp":.*?[^\\]",' | awk -F':' '{print $2}' | sed 's/[",]//g')
        fi
        echo -e "Location Information:"
        echo -e "Country: $country"
        echo -e "Region: $region"
        echo -e "City: $city"
        echo -e "Postal Code: $zip"
        echo -e "Latitude: $lat"
        echo -e "Longitude: $lon"
        echo -e "ISP: $isp"
    fi
}

main() {
    if [[ -n "$save_file" ]]; then
        exec > >(tee -a "$save_file") 2>&1
    fi
    if [[ "$output_json" == true ]]; then
        # Collect outputs in JSON format
        output_json_data="{"
        first=true
        if [[ "$include_public_ip" == true ]]; then
            display_public_ip_json=$(display_public_ip)
            output_json_data+="${display_public_ip_json#\{}"  # Remove starting '{'
            output_json_data="${output_json_data%\}}"  # Remove ending '}'
            first=false
        fi

        if [[ "$include_private_ip" == true ]]; then
            if [[ "$first" == false ]]; then
                output_json_data+=", "
            fi
            display_private_ip_json=$(display_private_ip)
            output_json_data+="${display_private_ip_json#\{}"
            output_json_data="${output_json_data%\}}"
            first=false
        fi

        if [[ "$include_location" == true ]]; then
            if [[ "$first" == false ]]; then
                output_json_data+=", "
            fi
            display_location_json=$(display_location)
            output_json_data+="\"location\": ${display_location_json#\{}"
            output_json_data="${output_json_data%\}}"
            first=false
        fi
        output_json_data+="}"
        echo "$output_json_data" | jq . 2>/dev/null || echo "$output_json_data"
    else
        # Plain text output
        if [[ "$include_public_ip" == true ]]; then
            display_public_ip
        fi
        if [[ "$include_private_ip" == true ]]; then
            display_private_ip
        fi
        if [[ "$include_location" == true ]]; then
            display_location
        fi
    fi
}

main
