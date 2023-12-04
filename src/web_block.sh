#!/usr/bin/env bash

# Script Name: web_block.sh
# Description: This script facilitates blocking or unblocking websites by modifying '/etc/hosts'.
# Usage: sudo ./web_block.sh [-a|-r] domain [-l] [-d]
# Example: sudo ./web_block.sh -a google.com -l (to block and log)

HOSTS_FILE="/etc/hosts"
BACKUP_FILE="/etc/hosts.bak"
LOG_FILE="/var/log/web_block.log"
LOG_ENABLED=0
DRY_RUN=0

function print_usage {
    echo "Usage: $0 [-a|-r] domain [-l] [-d]"
    echo "  -a: add (block) domain"
    echo "  -r: remove (unblock) domain"
    echo "  -l: enable logging"
    echo "  -d: dry run (no changes made)"
}

function log_action {
    [ $LOG_ENABLED -eq 1 ] && echo "$(date +"%Y-%m-%d %T"): $1" >> $LOG_FILE
}

function validate_domain {
    if ! [[ $1 =~ ^([a-zA-Z0-9-]+\.)*[a-zA-Z0-9-]+\.[a-zA-Z]{2,}$ ]]; then
        echo "Invalid domain name: $1"
        exit 1
    fi
}

function backup_hosts {
    cp $HOSTS_FILE $BACKUP_FILE
}

function modify_hosts {
    local action_msg
    if [[ $operation == "add" ]]; then
        if grep -q "127.0.0.1 $domain" $HOSTS_FILE; then
            action_msg="$domain is already blocked."
        else
            [ $DRY_RUN -eq 0 ] && echo "127.0.0.1 $domain" >> $HOSTS_FILE
            action_msg="Blocked $domain"
        fi
    else
        if grep -q "127.0.0.1 $domain" $HOSTS_FILE; then
            [ $DRY_RUN -eq 0 ] && sed -i "/^127.0.0.1 $domain$/d" $HOSTS_FILE
            action_msg="Unblocked $domain"
        else
            action_msg="$domain is not currently blocked."
        fi
    fi
    echo $action_msg
    log_action $action_msg
}

while getopts "arl:d" opt; do
    case $opt in
        a)
            operation="add"
            ;;
        r)
            operation="remove"
            ;;
        l)
            LOG_ENABLED=1
            ;;
        d)
            DRY_RUN=1
            ;;
        *)
            print_usage
            exit 1
            ;;
    esac
done

shift $((OPTIND -1))

domain=${1#www.}

[ -z "$operation" -o -z "$domain" ] && print_usage && exit 1
validate_domain $domain

if [ $(id -u) -ne 0 ]; then
    echo "Error: This script must be run as root"
    exit 1
fi

[ $DRY_RUN -eq 0 ] && backup_hosts
modify_hosts
