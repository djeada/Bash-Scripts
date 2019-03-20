#!/bin/bash
echo "Conversion of decimal to Binary and Binary to Decimal"
echo "1. Convert Decimal to Binary"
echo "2. Convert Binary to Decimal"
echo "3. Exit"
echo "Enter ur choice:"
read ch
case $ch in
1) echo "Enter any decimal no:"
read num
rem=1
bno=" "
while [ $num -gt 0 ]
do
rem=`expr $num % 2 `
bno=$bno$rem
num=`expr $num / 2 `
done
i=${#bno}
final=" "
while [ $i -gt 0 ]
do
rev=`echo $bno | awk '{ printf substr( $0,'$i',1 ) }'`
final=$final$rev
i=$(( $i - 1 ))
done
echo "Equivalent Binary no:" $final ;;
2) echo "Enter any Binary no;"
read bino
len=${#bino}
i=1
pow=$((len - 1 ))
while [ $i -le $len ]
do
n=`echo $bino | awk '{ printf substr( $0,'$i',1 )}' `
j=1
p=1
while [ $j -le $pow ]
do
p=$(( p * 2 ))
j=$(( j + 1 ))
done
dec=$(( n * p ))
findec=$(( findec + dec ))
pow=$((pow - 1 ))
i=$(( i + 1 ))
done
echo "Equivalent Decimal no:"$findec ;;
3) echo "Enter correctly:" ;;
esac


