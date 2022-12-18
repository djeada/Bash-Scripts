#!/usr/bin/env bash

# Script Name: clear_cache.sh
# Description: This script clears the local caches in the user's cache directory (e.g. `~/.cache`) that are older than a specified number of days.
# Usage: `clear_cache.sh [days]`
# Example: `clear_cache.sh 14` clears the local caches that are older than 14 days in the user's cache directory.

days="$1"

# Set default value for days if no argument is provided
if [ -z "$days" ]; then
  days=7
fi

find ~/.cache -depth -type f -mtime +"$days" -delete
