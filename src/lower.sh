
lower()
{
    # $1: string to lowercase

    # check if exactly one argument is given
    if [ $# -ne 1 ]; then
        echo "Usage: lower <string>"
        return 1
    fi

    # make string lowercase usin tr
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

lower "$@"
