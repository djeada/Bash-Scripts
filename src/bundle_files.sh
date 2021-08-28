#!/usr/bin/env bash

for i in $@; do
    if [ ! -f "$i" ]; then
        echo "$i does not exist."
        exit 1
    fi
    echo "unpacking file $i"
    echo "cat > $i <<EOF"
    cat $i
    echo "EOF"
done
