#!/usr/bin/env bash
read n

for (( i=0; i<n; i++ ))
do
    read x
    echo ${x:2:1}
done
