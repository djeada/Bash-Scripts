#!/bin/bash
read n
sum=0
for (( i = 0; i < n; i++ )); do
    read x
    sum=$((sum + x))
done

avg=$(bc <<< "scale=3;  $sum / $n")

echo $avg


