#!/bin/bash
num=$1
while [ $num -le 20 ]; do
	
# Don't print evens
if (( ((num % 2)) == 0 )); then
	num=$((num + 1))
 	continue
 fi
 		
 # Jump out of the loop with break
 if ((num >= 15)); then
 	break
 fi
 		
echo $num
num=$((num + 1))
done
