#!/bin/bash

read a
read b
read c

if [ $a == $b ] || [ $b == $c ] || [ $a == $c ] 
then
    if [ $a == $b ] && [ $b == $c ]
    then
        echo "EQUILATERAL"
    else
        echo "ISOSCELES"
    fi
else
    echo "SCALENE"
fi
