#!/usr/bin/env bash

paths=(src)
for path in "${paths[@]}"; do
    for script in $(find hooks -type l -name "[^_]*.sh"); do
        eval ""$script" "$path""
        echo -e "\nExecuting "$script""
    done
done

