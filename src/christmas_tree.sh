#!/usr/bin/env bash

triangle() {

    a=$1

    for (( i=0; i<$a; i++ )); do
        for (( j=0; j<=$i; j++ )); do
            echo -n "x"
        done
        echo ""
    done

}

christmas_tree() {

  n=$1

  for (( i=1; i<=$n; i++ )); do
      triangle $i
  done

}

main() {

  if [ $# -eq 0 ]; then
    echo "Must provide the expression to be evaluated!"
    exit 1
  fi

  christmas_tree $1

}

main "$@"
