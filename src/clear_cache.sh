#!/usr/bin/env bash

# Script Name: clear_cache.sh
# Description: This script clears local caches in the user's cache directory (e.g. `~/.cache`)
#              that are older than a specified number of days or all caches if '-all' option is provided.
#              A dry run option '-dry' can also be used to show the files that will be deleted.
# Usage: `clear_cache.sh [days|-all|-dry]`
# Example: `clear_cache.sh 14` clears local caches older than 14 days.
#          `clear_cache.sh -all` clears all local caches.
#          `clear_cache.sh -dry` shows the files that will be deleted without deleting them.

days="$1"
dry_run=0

if [ "$days" = "-all" ]; then
    days=0
elif [ "$days" = "-dry" ]; then
    days=0
    dry_run=1
elif ! [[ "$days" =~ ^[0-9]+$ ]] || [[ "$days" -lt 0 ]]; then
    echo "Please provide a valid number of days or '-all' to clear all caches or '-dry' for a dry run."
    exit 1
fi

if [[ "$dry_run" -eq 1 ]]; then
    echo "Dry run. The following files will be deleted:"
    find ~/.cache -depth -type f -mtime +"$days"
else
    find ~/.cache -depth -type f -mtime +"$days" -delete
fi

