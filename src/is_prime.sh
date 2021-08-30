#!/usr/bin/env bash

is_prime() {

    a=$1

    if [[ $a -eq 2 ]] || [[ $a -eq 3 ]]; then
        return 1
    fi

    if [[ $(($a % 2)) -eq 0 ]] || [[ $(($a % 3)) -eq 0 ]]; then
        return 0
    fi

    i=5
    w=2

    while [[ $((i * i)) -le $a ]]; do

        if [[ $(($a % i)) -eq 0 ]]; then
            return 0
        fi

        i=$((i + w))
        w=$((6 - w))
    done

    return 1
}


main() {

  if [ $# -eq 0 ]; then
    echo "Must provide the expression to be evaluated!"
    exit 1
  fi

  if [[ $((is_prime $1)) -eq 1 ]]; then
      echo "$1 one is a prime number!"
  else
      echo "$1 is not a prime number!"
  fi
  
}

main "$@"
