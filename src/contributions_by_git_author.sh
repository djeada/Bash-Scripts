#!/usr/bin/env bash

# Get the email address of the author that we want to count the lines for
author_email=$1

# Use git log to get a list of commits, with the short stat summary and the email address of the author
git_log=$(git log --shortstat --pretty="%cE")

# Use sed to extract the username from the email address (everything before the "@" symbol)
usernames=$(echo "$git_log" | sed 's/\(.*\)@.*/\1/')

# Use grep to remove any blank lines
usernames=$(echo "$usernames" | grep -v "^$")

# Use awk to process the list of usernames and commit stats
awk_output=$(echo "$usernames" | awk 'BEGIN { line=""; } !/^ / { if (line=="" || !match(line, $0)) {line = $0 "," line }} /^ / { print line " # " $0; line=""}' | sort)

# Use sed to reformat the commit stats
sed_output=$(echo "$awk_output" | sed -E 's/# //;s/ files? changed,//;s/([0-9]+) ([0-9]+ deletion)/\1 0 insertions\(+\), \2/;s/\(\+\)$/\(\+\), 0 deletions\(-\)/;s/insertions?\(\+\), //;s/ deletions?\(-\)//')

# Use awk to summarize the commit stats by username
awk_output=$(echo "$sed_output" | awk -v author="$author_email" 'BEGIN {name=""; files=0; insertions=0; deletions=0;} {if ($1 != name && name != "") { if (name == author) { print name ": " files " files changed, " insertions " insertions(+), " deletions " deletions(-), " insertions-deletions " net"; } files=0; insertions=0; deletions=0; name=$1; } name=$1; files+=$2; insertions+=$3; deletions+=$4} END {if (name == author) { print name ": " files " files changed, " insertions " insertions(+), " deletions " deletions(-), " insertions-deletions " net";}}')

# Print the final output
echo "$awk_output"
