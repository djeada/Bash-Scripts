
ask_question_and_get_response ()
{
    # $1 is the question
    # $2 is the default answer

    # check the number of arguments
    if [ $# -eq 0 ]; then
        echo "No arguments supplied"
        exit 1
    fi

    # check if the first argument is a string
    if [ -z "$1" ]; then
        echo "First argument is not a string"
        exit 1
    fi

    if [ $# -eq 2 ]; then
        # check if the second argument is a string
        if [ -z "$2" ]; then
            echo "Second argument is not a string"
            exit 1
        fi
        
        response="$2"
    fi

    echo -e "$1"
    read -p "[$response]"$'\n' response
}

# Ask for the user's name
ask_question_and_get_response "What is your name?" "John Doe"
echo "Hello $response"
