#!/usr/bin/env bash

main() {

    for old_name in $@; do
        if [ ! -f "$i" ]; then
            echo "$i does not exist."
            exit 1
        fi
        
        new_name=`echo $old_name | sed -e 's/ /_/g'` | tr '[:upper:]' '[:lower:]'` 
        mv "$old_name" "$new_name" 
    done

}

main "$@"
