#!/usr/bin/env bash

# Script Name: dead_code.sh
# Description: Finds classes, functions, and variables 
# that are declared but never used in the code.
# Usage: dead_code.sh [<project_path>]
#        [<project_path>] - path to the project to analyze (defaults to current directory).
# Example: ./dead_code.sh path/to/project

# find all python files in src/ 

function_names=()

for file in $(find src/ -name "*.py")
    # get file contents
    file_contents=$(cat $file)

    # get all function names and remove the 'def'
    function_names_in_file=$(echo $file_contents | grep -o -E 'def [a-zA-Z0-9_]+' | sed 's/def //g')

    # add function names to the dictionary, key is the file name, value is the list of function names
    function_names+=([$file]=$function_names_in_file)
done

# iterate over the dictionary and check how many times a function is called in all files in src/
for key in "${!function_names[@]}"
    do
        # get the list of function names
        function_names_in_file=${function_names[$key]}

        # iterate over the list of function names and check how many times they are called
        for function_name in $function_names_in_file
            do
                # get the number of times the function is called
                # it has to appear either in the file it was declared in or in a file that imports it 
                # using the file name associated with the function name
                number_of_times_called=$(grep -o -E $function_name src/*.py | wc -l)

                # if the function is called more than once, remove it from the list of function names
                if [ $number_of_times_called -gt 1 ]
                    then
                        function_names_in_file=$(echo $function_names_in_file | sed "s/$function_name//g")
                fi
        done

        # update the list of function names in the dictionary
        function_names[$key]=$function_names_in_file
done