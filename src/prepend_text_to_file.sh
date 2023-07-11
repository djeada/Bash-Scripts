#!/bin/bash

# Function Name: prepend_text_to_file
# Description: This function prepends provided text to the specified file.
# If the file does not exist, it will be created, and the text will be written to it.
# Usage: prepend_text_to_file <file> <text>

prepend_text_to_file() {

    # Validate the number of arguments
    if [ $# -ne 2 ]; then
        echo "Error: Incorrect number of arguments."
        echo "Usage: prependTextToFile <file> <text>"
        return 1
    fi

    local file="$1"
    local text="$2"

    # Handle the case where the file does not exist by creating it
    if [ ! -f "$file" ]; then
        echo "Notice: File '$file' does not exist. Creating file..."
        touch "$file"
    fi

    # Prepend the text to the file
    { echo "$text"; cat "$file"; } > "temp" && mv "temp" "$file"

    # Display log info in the console
    echo "The following text was prepended to the file '$file':"
    echo "$text"
}

main() {
    # Call the function
    prepend_text_to_file "$1" "$2"
}

main "$@"

