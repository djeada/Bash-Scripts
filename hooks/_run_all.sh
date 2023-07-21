#!/usr/bin/env bash

# Script Name: _run_all.sh
# Description: This script will check all scripts in the specified paths.
#              It finds all the scripts (not starting with _) in the 'hooks' directory and executes them with '--check' option.
#              The path for the check is specified in the 'paths' array.
#              At the end, it will exit with 1 if any check failed.

# Paths to check
paths=(src)

# Status variable to track if any check fails
status=0

# Process each path
for path in "${paths[@]}"; do
    # Find all scripts (not starting with _) in 'hooks' directory
    for script in $(find hooks -type l -name "[^_]*.sh"); do
        echo -e "\nExecuting "$script""

        # Execute the script with '--check' option
        "$script" --check "$path" || { echo "$script check on $path failed"; status=1; }
    done
done

# Exit with 1 if any check failed
if [[ $status -eq 1 ]]; then
    exit 1
fi

