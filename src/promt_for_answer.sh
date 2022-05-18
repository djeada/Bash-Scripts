
ask_question_and_get_response ()
{
    # $1 is the question
    # $2 is the default answer

    # check the number of arguments
    if [ $# -eq 0 ]; then
        echo "No arguments supplied"
        exit 1
    fi

    echo -e "$1"
    read -p "[$2]"$'\n' response

    if [ $# -eq 2 ]; then
        if [ -z "$response" ]; then
            response="$2"
        fi
    fi
}

# Ask for the user's name
ask_question_and_get_response "What is your name?"
echo "Hello $response"
