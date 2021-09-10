#!/usr/bin/env bash

main() {

    if [ -n "$(command -v apt | wc -l)" != "1" ]
    then
      echo "The apt command is not accessible on this system."
      exit 1
    fi

}

main "$@"
