#!/bin/bash
read N
if (($N == 1)); then 
    echo $N
else 
    array=($(cat))
    x=${array[0]}
	end=$((N-2))
	for ((i=1;i<$end;i++))
    do
        if [ $x -eq ${array[i]} ]; then
            x=${array[i+1]}
		fi
    done
    echo $x
fi

