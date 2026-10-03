#!/usr/bin/env bash

# Script Name: html_table_to_markdown.sh
# Description: Converts the HTML table rows in a file to a Markdown table.
#              Rows containing <th> cells become the header row. Requires GNU grep (-P).
# Usage: ./html_table_to_markdown.sh html_file

print_usage() {
    echo "Usage: $0 html_file"
    echo "Converts an HTML table in the specified file to a Markdown table."
}

convert_row_to_markdown() {
    local row=$1
    local cells cell line=""

    # Extract the cells (non-greedy so adjacent cells are not merged)
    mapfile -t cells < <(grep -oiP '<t[hd][^>]*>.*?</t[hd]>' <<< "$row")
    [[ ${#cells[@]} -gt 0 ]] || return 0

    for cell in "${cells[@]}"; do
        # Strip HTML tags, trim whitespace and escape pipes
        cell=$(sed -e 's/<[^>]*>//g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/|/\\|/g' <<< "$cell")
        line+="| $cell "
    done
    echo "${line}|"

    # Header rows are followed by the Markdown separator line
    if grep -qi '<th' <<< "$row"; then
        printf '|'
        printf ' --- |%.0s' "${cells[@]}"
        echo
    fi
}

# Check the number of arguments
if [[ $# -ne 1 ]]; then
    echo "Error: Incorrect number of arguments." >&2
    print_usage >&2
    exit 1
fi

html_file="$1"

if [[ ! -f $html_file ]]; then
    echo "Error: File $html_file not found." >&2
    exit 1
fi

# Join the file into one line (so rows spanning several lines work), then
# extract the table rows
mapfile -t rows < <(tr '\n\r' '  ' < "$html_file" | grep -oiP '<tr[^>]*>.*?</tr>')

if [[ ${#rows[@]} -eq 0 ]]; then
    echo "Error: No table rows found in $html_file." >&2
    exit 1
fi

# Convert each table row to Markdown
for row in "${rows[@]}"; do
    convert_row_to_markdown "$row"
done

