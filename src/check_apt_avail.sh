#!/usr/bin/env bash

main() {

    if [ $(command -v apt | wc -l) -ne 1  ]
    then
      echo "The apt command is not accessible on this system."
      exit 1
    fi

}

main "$@"
