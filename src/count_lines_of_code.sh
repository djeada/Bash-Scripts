#!/usr/bin/env bash

main() {

   git ls-files -z | xargs -0 wc -l | awk 'END{print}'

}

main "$@"
