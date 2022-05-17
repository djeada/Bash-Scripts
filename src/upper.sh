
upper()
{
    # $1: string to uppercase

    # check if exactly one argument is given
    if [ $# -ne 1 ]; then
        echo "Usage: upper <string>"
        return 1
    fi

    # make string uppercase usin tr
    echo "$1" | tr '[:lower:]' '[:upper:]'
}

upper "$@"
