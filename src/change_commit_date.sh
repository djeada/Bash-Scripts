#!/usr/bin/env bash

# TODO: accept only the date, use random time, and calculate the day of the week based on the date

LC_ALL=C GIT_COMMITTER_DATE="$1 +0100" git commit --amend --no-edit --date "$1 +0100"

