
prepend_text_to_file() {

    # assure number of arguments is correct
    if [ $# -ne 2 ]; then
        echo "Usage: prepend_text_to_file <file> <text>"
        return 1
    fi

    local file="$1"
    local text="$2"

    if [ -f "$file" ]; then
        echo "$text" | cat - "$file" > temp && mv temp "$file"
    else
        echo "$text" > "$file"
    fi

    # Display log info in the console
    echo "The following text was added to the file $file:"
    echo "$text"

}


main() {

    # call the function
    prepend_text_to_file "$1" "$2"

}

main "$@"
