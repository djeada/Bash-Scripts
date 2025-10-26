#!/usr/bin/env bash
#
# Script Name: replace_everywhere.sh
# Description: Replace string a with string b in all files in the current directory and subdirectories.
#              Skips hidden directories by default. Optionally exclude specific subdirectories.
#
# Usage:
#   replace_everywhere.sh [options] <string_a> <string_b>
#
# Options:
#   -x, --exclude DIR    Exclude a subdirectory (repeatable). Examples: -x node_modules -x build
#       --include-hidden Include hidden directories (like .git, .venv).
#   -h, --help           Show this help and exit.
#
# Examples:
#   replace_everywhere.sh "cat" "dog"
#   replace_everywhere.sh -x dist -x build 'string with space' 'new string'
#   replace_everywhere.sh --include-hidden 'foo**' 'bar\baz'
#
# Notes:
# - For literal matching, special chars are handled safely. Replacement also escapes '&' properly.
# - Works on GNU sed and BSD/macOS sed.

set -euo pipefail

print_usage() {
  sed -n '2,40p' "$0"
}

# Escape a string for use as a *literal* sed pattern (s/…/…/)
escape_sed_pattern() {
  # Escapes: \ / [ ] . ^ $ * and other regex metas so the pattern is treated literally
  printf '%s' "$1" | sed -e 's/[.[\*^$\/]/\\&/g' -e 's/]/\\]/g'
}

# Escape replacement for sed (so '&' doesn't expand to the whole match)
escape_sed_replacement() {
  local s=$1
  s=${s//\\/\\\\}   # escape backslashes first
  s=${s//&/\\&}     # then ampersands
  printf '%s' "$s"
}

main() {
  local include_hidden=false
  local -a excludes=()

  # Parse args (support short and long)
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -x|--exclude)
        [[ $# -lt 2 ]] && { echo "Missing argument for $1" >&2; exit 2; }
        excludes+=("$2"); shift 2;;
      --include-hidden)
        include_hidden=true; shift;;
      -h|--help)
        print_usage; exit 0;;
      --) shift; break;;
      -*)
        echo "Unknown option: $1" >&2; print_usage; exit 2;;
      *)
        break;;
    esac
  done

  if [[ $# -ne 2 ]]; then
    print_usage
    exit 1
  fi

  local search_raw="$1"
  local replace_raw="$2"

  local search replace
  search=$(escape_sed_pattern "$search_raw")
  replace=$(escape_sed_replacement "$replace_raw")

  # Confirm action
  read -r -p "Replace ALL occurrences of '$search_raw' with '$replace_raw' in this tree? [y/N] " confirmation
  if [[ ! $confirmation =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 1
  fi

  # Detect GNU vs BSD sed for in-place flag
  local -a SED_INPLACE
  if sed --version >/dev/null 2>&1; then
    SED_INPLACE=(-i)
  else
    # macOS/BSD sed needs a backup suffix (empty is allowed)
    SED_INPLACE=(-i '')
  fi

  # Build the find prune predicates
  # Start with hidden directories (if not including them)
  local -a PRUNE_BLOCK=()
  if [[ "$include_hidden" == false ]]; then
    PRUNE_BLOCK+=( -path './.*' -prune -o )
  fi

  # Add user-specified excludes (treat as directory names/paths from repo root)
  if [[ ${#excludes[@]} -gt 0 ]]; then
    for d in "${excludes[@]}"; do
      # Normalize leading './'
      [[ "$d" != ./* ]] && d="./$d"
      PRUNE_BLOCK+=( -path "$d" -prune -o )
    done
  fi

  # Execute replacement
  if [[ ${#PRUNE_BLOCK[@]} -gt 0 ]]; then
    find . \( "${PRUNE_BLOCK[@]}" -false \) -o -type f \
      -exec sed "${SED_INPLACE[@]}" "s/${search}/${replace}/g" {} +
  else
    find . -type f \
      -exec sed "${SED_INPLACE[@]}" "s/${search}/${replace}/g" {} +
  fi

  echo "Done."
}

main "$@"
