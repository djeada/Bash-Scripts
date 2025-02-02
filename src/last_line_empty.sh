#!/usr/bin/env bash
#
# Usage: ./last_line_empty.sh <file> > <output-file>
#
# 1) Reads <file> line by line into memory.
# 2) Counts trailing *completely empty* lines (no characters at all).
# 3) If trailing empty lines == 0, add 1 empty line.
#    If trailing empty lines == 1, leave as is.
#    If trailing empty lines  > 1, remove extras so exactly 1 remains.
# 4) Writes the result to stdout.
#
# Example:
#   ./last_line_empty.sh myfile.txt > myfile_fixed.txt
#   mv myfile_fixed.txt myfile.txt
#

file="$1"

# Basic argument check
if [[ -z "$file" ]]; then
  echo "Error: no file specified." >&2
  exit 1
fi

# Must be a regular file
if [[ ! -f "$file" ]]; then
  echo "Error: '$file' is not a regular file." >&2
  exit 1
fi

# Read the entire file into an array, one line per element
# (Note: This will strip trailing newline(s) from the last line read,
#  which is normal mapfile behavior.)
mapfile -t lines < "$file"

# Number of lines in the file
num_lines="${#lines[@]}"

# If file is empty (no lines), just output one empty line
# (since we have 0 trailing empty lines, we add 1)
if (( num_lines == 0 )); then
  echo ""
  exit 0
fi

# Count how many empty lines from the end
empty_count=0
for (( i=num_lines-1; i>=0; i-- )); do
  if [[ "${lines[$i]}" == "" ]]; then
    (( empty_count++ ))
  else
    break
  fi
done

# Decide how many lines to keep
# Cases:
#   empty_count == 0  => add one empty line
#   empty_count == 1  => unchanged
#   empty_count > 1   => remove extras so that only one remains
if (( empty_count == 0 )); then
  # Print all lines, then add exactly one empty line
  for line in "${lines[@]}"; do
    echo "$line"
  done
  echo ""

elif (( empty_count == 1 )); then
  # Just print all lines as is
  for line in "${lines[@]}"; do
    echo "$line"
  done

else
  # Keep everything up to the last (empty_count - 1) lines
  # We want to remove extra empty lines, leaving exactly 1 trailing
  # So we keep lines from 0 .. (num_lines - empty_count)
  keep_last_index=$(( num_lines - empty_count ))
  # Print lines up to that point
  for (( i=0; i<keep_last_index; i++ )); do
    echo "${lines[$i]}"
  done
  # Then print exactly one empty line
  echo ""
fi
