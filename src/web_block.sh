#!/usr/bin/env bash

# Script Name: web_block
# Description: This script facilitates blocking or unblocking websites on the local machine by modifying the '/etc/hosts' file.
# Usage: ./web_block.sh [-add|-remove] domain
# Example: ./web_block.sh -add google.com

function print_usage {
    echo "Usage: $0 [-add|-remove] domain"
}

function require_root {
    # Validate that the script is run as root
    if [[ $(id -u) -ne 0 ]]
    then
        echo "Error: This script must be run as root"
        exit 1
    fi
}

function validate_args {
    # Validate argument count
    if [[ $# -lt 2 ]]
    then
        echo "Error: Insufficient arguments provided"
        print_usage
        exit 1
    fi

    # Parse and validate arguments
    operation=$1
    domain=$2
    domain=${domain#www.} # Strip 'www' from domain

    if [[ "$operation" != "-add" && "$operation" != "-remove" ]]
    then
        echo "Error: Invalid operation: $operation"
        print_usage
        exit 1
    fi
}

function modify_hosts {
    if [[ "$operation" == "-add" ]]
    then
        # Add the domain to the hosts file
        echo "127.0.0.1 $domain" >> /etc/hosts
        echo "127.0.0.1 www.$domain" >> /etc/hosts
        echo "$domain has been blocked successfully."
    else
        # Remove the domain from the hosts file
        sed -i "/^127.0.0.1 $domain$/d" /etc/hosts
        sed -i "/^127.0.0.1 www.$domain$/d" /etc/hosts
        echo "$domain has been unblocked successfully."
    fi
}

# Execute functions
require_root
validate_args "$@"
modify_hosts
