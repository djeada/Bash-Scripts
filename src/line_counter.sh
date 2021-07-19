#!/bin/bash

if [ -z "$1" ]
then
    echo "No argument supplied"
    exit 1
fi

fileName=$1

if [ ! -f "$fileName" ]; then
    echo "$fileName does not exist."
    exit 1
fi

counter=0

while read p; do
    ((counter++))
done < $fileName

echo "Number of lines in ${fileName} is: ${counter}"
