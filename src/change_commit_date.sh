#!/usr/bin/env bash

LC_ALL=C GIT_COMMITTER_DATE="$1 +0100" git commit --amend --no-edit --date "$1 +0100"

