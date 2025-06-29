#!/usr/bin/env bash

# Script Name: html_table_to_markdown.sh
# Description: Converts an HTML table to a Markdown table.
# Usage: ./html_table_to_markdown.sh [html_file]

print_usage() {
    echo "Usage: $0 [html_file]"
    echo "Converts an HTML table in the specified file to a Markdown table."
}

convert_row_to_markdown() {
    local row=$1
    local row_type=$2 # 'header' or 'data'

    # Detect if the row is a header or data
    if [[ $row =~ "<th" ]]; then
        row_type="header"
    else
        row_type="data"
    fi

    # Extract cells and convert to Markdown
    row=$(echo "$row" | sed -e 's/<\/\?\(th\|td\)[^>]*>//g' -e 's/^\s*//g' -e 's/\s*$//g')
    local IFS=$'\n'
    local cells
    mapfile -t cells < <(grep -o '<td>.*</td>\|<th>.*</th>' <<< "$row")
    local markdown_cells=()

    for cell in "${cells[@]}"; do
        # Strip HTML tags and escape pipes
        cell=$(echo "$cell" | sed -e 's/<[^>]*>//g' -e 's/|/\\|/g')
        markdown_cells+=("$cell")
    done

    if [ "$row_type" == "header" ]; then
        echo "| ${markdown_cells[*]} |"
        printf '|%s' "$(yes ' --- |' | head -n ${#markdown_cells[@]})"
        echo '|'
    else
        echo "| ${markdown_cells[*]} |"
    fi
}

# Check the number of arguments
if [[ $# -ne 1 ]]; then
    echo "Error: Incorrect number of arguments."
    print_usage
    exit 1
fi

html_file="$1"

if [[ ! -f $html_file ]]; then
    echo "Error: File $html_file not found."
    exit 1
fi

# Extract the table rows from the HTML file
rows=$(grep -oP '<tr>.+?</tr>' "$html_file")

# Convert each table row to Markdown
while IFS= read -r row; do
    convert_row_to_markdown "$row"
done <<< "$rows"
