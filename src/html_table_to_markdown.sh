#!/usr/bin/env bash

# Script Name: html_table_to_markdown
# Description: This script converts an HTML table to a Markdown table.
# Usage: ./html_table_to_markdown.sh [html_file]
# Example: ./html_table_to_markdown.sh table.html

# Function to print script usage
print_usage() {
    echo "Usage: $0 [html_file]"
    echo "Converts an HTML table in the specified file to a Markdown table."
}

# Check the number of arguments
if [[ $# -ne 1 ]]; then
    echo "Error: Incorrect number of arguments."
    print_usage
    exit 1
fi

html_file="$1"

# Check if file exists
if [[ ! -f $html_file ]]; then
    echo "Error: File $html_file not found."
    exit 1
fi

# Extract the table rows from the HTML file
rows=$(grep -oP '<tr>.+?</tr>' "$html_file")

# Initialize an empty array to store the Markdown table rows
declare -a markdown_rows

# Convert each table row to Markdown
while IFS= read -r row; do
    # Extract the table cells from the row
    cells=$(grep -oP '<td>.+?</td>' <<< "$row")

    # Initialize an empty array to store the Markdown table cells
    declare -a markdown_cells

    # Convert each table cell to Markdown
    while IFS= read -r cell; do
        # Strip the HTML tags from the cell
        cell=$(sed 's/<[^>]*>//g' <<< "$cell")
        # Escape pipes and dashes in the cell
        cell=$(sed 's/|/\\|/g; s/-/\\-/g' <<< "$cell")
        # Add the cell to the array
        markdown_cells+=("$cell")
    done <<< "$cells"

    # Join the Markdown cells with pipes and add the row to the array
    markdown_row=$(IFS='|'; printf '| %s |\n' "${markdown_cells[*]}")
    markdown_rows+=("$markdown_row")
done <<< "$rows"

# Join the Markdown rows with newlines and print the table
markdown_table=$(IFS=$'\n'; echo "${markdown_rows[*]}")
echo -e "$markdown_table"

