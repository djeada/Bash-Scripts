#!/usr/bin/env bash

# Script Name: html_table_to_markdown.sh
# Description: This script converts an HTML table to a Markdown table.
# Usage: `html_table_to_markdown.sh [html_file]`
# Example: `html_table_to_markdown.sh table.html` converts the HTML table in the file `table.html` to a Markdown table.

html_file="$1"

# Extract the table rows from the HTML file
rows=$(grep -oP '<tr>.+?</tr>' "$html_file")

# Initialize an empty array to store the Markdown table rows
markdown_rows=()

# Convert each table row to Markdown
for row in $rows; do
  # Extract the table cells from the row
  cells=$(grep -oP '<td>.+?</td>' <<< "$row")

  # Initialize an empty array to store the Markdown table cells
  markdown_cells=()

  # Convert each table cell to Markdown
  for cell in $cells; do
    # Strip the HTML tags from the cell
    cell=$(sed 's/<[^>]*>//g' <<< "$cell")
    # Escape pipes and dashes in the cell
    cell=$(sed 's/|/\\|/g; s/-/\\-/g' <<< "$cell")
    # Add the cell to the array
    markdown_cells+=("$cell")
  done

  # Join the Markdown cells with pipes and add the row to the array
  markdown_row=$(IFS='|'; printf '| %s |\n' "${markdown_cells[*]}")
  markdown_rows+=("$markdown_row")
done

# Join the Markdown rows with newlines and print the table
markdown_table=$(IFS=$'\n'; printf '%s\n' "${markdown_rows[*]}")
echo "$markdown_table"
