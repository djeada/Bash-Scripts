#!/usr/bin/env bash

if [ $# -eq 0 ]; then
    echo "Must provide the expression to be evaluated!"
    exit 1
fi

echo "scale=5; $1" | bc -l | awk '{printf "%.3f\n", $1}'
