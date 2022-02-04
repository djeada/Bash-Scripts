#!/usr/bin/env bash

# TODO: accept only the date, use random time, and calculate the day of the week based on the date

week_day() {
    
   DD="$1"
   MM="$2"
   YY="$3"

   CC=$(( YY/100))
    YY=$(( YY % 100))

    A=$((( CC/4) - 2*CC - 1))
    B=$((5* YY/4))
    C=$((26*(MM+1)/10))

    local result
    result=$(((A + B + C + DD) % 7))

    if [[ "$result" -eq 1 ]]; then
        echo "MON"

    elif [[ "$result" -eq 2 ]]; then
        echo "TUE"

    elif [[ "$result" -eq 3 ]]; then
        echo "WEN"

    elif [[ "$result" -eq 4 ]]; then
        echo "THU"

    elif [[ "$result" -eq 5 ]]; then
        echo "FRI"

    elif [[ "$result" -eq 6 ]]; then
        echo "SAT"

    elif [[ "$result"t -eq 7 ]]; then
        echo "SUN"

    else
        echo "Can't parse the date!"
        exit 1
    fi

}



main() {

    if [ $# -ne 1 ]; then
       echo "You have to provide the new date!"
       exit 1
    fi
    
    date="$1"
    
    LC_ALL=C GIT_COMMITTER_DATE="$1 +0100" git commit --amend --no-edit --date "$1 +0100"


}
