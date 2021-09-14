#!/usr/bin/env bash

# TODO: working_dir and branch names as parameter

main() {

  git fetch origin
  git reset --hard origin/master
  git clean -fdx

}

main "$@"
