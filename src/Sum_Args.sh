#!/bin/bash
echo "Arguments submitted: "
	
sum=0
for i; do
 echo $i
done

	
# $# tells you the number of arguments
while [[ $# -gt 0 ]]; do
	
# Get the first argument
	num=$1
	sum=$((sum + num))
		
	# shift moves the value of $2 into $1 until none are left
	# The value of $# decrements as well
	shift
done
	
echo "Sum of the arguments: $sum"
