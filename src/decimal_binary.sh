#!/usr/bin/env bash

main() {

    echo "Conversion of a decimal number $1 to it's binary representation.\n"

    if [ $# -ne 1 ]; then
        echo "Must provide the expression to be evaluated!"
        exit 1
    fi

    num=$1
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

    echo "Binary representation:" $final

}

main "$@"

