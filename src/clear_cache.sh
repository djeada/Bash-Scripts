#!/usr/bin/env bash

# Script Name: clear_cache.sh
# Description: Clears local caches in the specified user's cache directory.
# Usage: clear_cache.sh [days|-all|-dry] [-d directory] [-l log_file]
# Example: clear_cache.sh 14 -d ~/.cache - Clears caches older than 14 days in ~/.cache.

LOG_FILE="/var/log/clear_cache.log"
LOG_ENABLED=0
days=0
dry_run=0
cache_dir=~/.cache

function log_action {
    [ $LOG_ENABLED -eq 1 ] && echo "$(date +"%Y-%m-%d %T"): $1" >> $LOG_FILE
}

function print_usage {
    echo "Usage: $0 [days|-all|-dry] [-d directory] [-l log_file]"
    echo "  -d: specify cache directory (default: ~/.cache)"
    echo "  -l: enable logging to specified log file"
}

function confirm_deletion {
    read -p "Are you sure you want to delete these files? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

while getopts ":d:l:" opt; do
    case $opt in
        d)
            cache_dir=$OPTARG
            ;;
        l)
            LOG_FILE=$OPTARG
            LOG_ENABLED=1
            ;;
        \?)
            print_usage
            exit 1
            ;;
    esac
done

shift $((OPTIND - 1))
days=$1

if [ "$days" = "-all" ]; then
    days=0
elif [ "$days" = "-dry" ]; then
    dry_run=1
    days=0
elif ! [[ "$days" =~ ^[0-9]+$ ]] || [[ "$days" -lt 0 ]]; then
    echo "Invalid argument. Please provide a valid number of days, '-all', or '-dry'."
    print_usage
    exit 1
fi

if [[ "$dry_run" -eq 1 ]]; then
    echo "Dry run. The following files would be deleted:"
    find "$cache_dir" -depth -type f -mtime +"$days"
    log_action "Performed dry run for cache clearing."
else
    echo "Deleting files in $cache_dir older than $days days..."
    if [ "$days" -eq 0 ] || confirm_deletion; then
        find "$cache_dir" -depth -type f -mtime +"$days" -delete
        log_action "Deleted files in cache directory."
    else
        echo "Deletion cancelled."
        log_action "Cache deletion cancelled by user."
    fi
fi
