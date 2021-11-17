#!/usr/bin/env bash

# Script Name: web_block.sh
# Description: Block websites from being visited.
# Usage: web_block.sh [add|remove] [<website>]
#      add - Add a website to the block list.
#      remove - Remove a website from the block list.
#      <website> - The website to block.
# Example: web_block.sh add www.example.com

append_domain() {
    local domain="$1"
    # strip www from url
    local domain="${domain#www.}"

    echo "0.0.0.0 $domain" >> /etc/hosts
    echo "0.0.0.0 www.$domain" >> /etc/hosts
    echo "::0 $domain" >> /etc/hosts
    echo "::0 www.$domain" >> /etc/hosts
}

remove_domain() {
    local domain="$1"
    # strip www from url
    local domain="${domain#www.}"

    sed -i "/$domain/d" /etc/hosts
    sed -i "/www.$domain/d" /etc/hosts
}

main() {
    
    if [ $# -ne 2 ]; then
        echo "Usage: $0 <action> <domain>"
        echo "  <action>  'add' or 'remove'"
        echo "  <domain>  Domain to block"
        exit 1
    fi
    
    local action="$1"
    local domain="$2"

    if [ "$action" == "add" ]; then
        append_domain "$domain"
    elif [ "$action" == "remove" ]; then
        remove_domain "$domain"
    else
        echo "Usage: $0 <action> <domain>"
        echo "  <action>  'add' or 'remove'"
        echo "  <domain>  Domain to block"
        exit 1
    fi
}

main "$@"
