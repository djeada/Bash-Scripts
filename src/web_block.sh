#!/usr/bin/env bash

# Script Name: web_block.sh
# Description: A Bash script to block or unblock websites on the local machine by modifying the 'hosts' file.
# Usage: web_block.sh [-add|-remove] domain
# Example: web_block.sh -add google.com

# Check if the script is run as root
if [[ $(id -u) -ne 0 ]]
then
    echo "This script must be run as root"
    exit 1
fi

# Display usage if no argument is provided
if [[ $# -lt 2 ]]
then
    echo "Usage: $0 [-add|-remove] domain"
    exit 1
fi

# Parse arguments
operation=$1
domain=$2

# Strip www from domain
domain=${domain#www.}

# Check if the operation is valid
if [[ "$operation" != "-add" && "$operation" != "-remove" ]]
then
    echo "Invalid operation: $operation"
    echo "Usage: $0 [-add|-remove] domain"
    exit 1
fi

# Modify the hosts file
if [[ "$operation" == "-add" ]]
then
    # Add the domain to the hosts file
    echo "127.0.0.1 $domain" >> /etc/hosts
    echo "127.0.0.1 www.$domain" >> /etc/hosts
    echo "$domain has been added to the blocklist"
else
    # Remove the domain from the hosts file
    sed -i "/$domain/d" /etc/hosts
    sed -i "/www.$domain/d" /etc/hosts
    echo "$domain has been removed from the blocklist"
fi
