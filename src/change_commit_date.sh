#!/usr/bin/env bash

# LC_ALL=C GIT_COMMITTER_DATE="Wed Feb 16 14:00 2020 +0100" git commit --amend --no-edit --date "Wed Feb 16 14:00 2020 +0100"
abs() { 
    [[ $[ $@ ] -lt 0 ]] && echo "$[ ($@) * -1 ]" || echo "$[ $@ ]"
}

day_string_converter() {

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

    if [ $result -lt 0 ]; then
    A=$(abs "$A")
    B=$(abs "$B")
    C=$(abs "$C")
    result=$(((A + B + C + DD) % 7))
    fi
    
    if [[ "$result" -eq 1 ]]; then
        echo "Mon"

    elif [[ "$result" -eq 2 ]]; then
        echo "Tue"

    elif [[ "$result" -eq 3 ]]; then
        echo "Wen"

    elif [[ "$result" -eq 4 ]]; then
        echo "Thu"

    elif [[ "$result" -eq 5 ]]; then
        echo "FRI"

    elif [[ "$result" -eq 6 ]]; then
        echo "Sat"

    elif [[ "$result" -eq 0 ]]; then
        echo "Sun"

    else
        echo "Can't parse the date!"
        exit 1
    fi

}

month_string_converter() {
    case $1 in
        1)
            echo "Jan"
            ;;
        2)
            echo "Feb"
            ;;
        3)
            echo "Mar"
            ;;
        4)
            echo "Apr"
            ;;
        5)
            echo "May"
            ;;
        6)
            echo "Jun"
            ;;
        7)
            echo "Jul"
            ;;
        8)
            echo "Aug"
            ;;
        9)
            echo "Sep"
            ;;
        10)
            echo "Oct"
            ;;
        11)
            echo "Nov"
            ;;
        12)
            echo "Dec"
            ;;
        *)
            echo "Can't parse the date!"
            exit 1
            ;;
    esac
}

random_time() {
    # random hour between 0 and 23
    # random minute between 0 and 59
    echo "$((RANDOM % 24)):$((RANDOM % 60))"
}

validate_date() {
    date="$1"
    # split on -
    IFS='-' read -r -a date_array <<< "$date"
    # check if the array has 3 elements
    if [ ${#date_array[@]} -ne 3 ]; then
        echo "Can't parse the date!"
        exit 1
    fi
    day="${date_array[0]}"
    month="${date_array[1]}"
    year="${date_array[2]}"
    # check if the day is a number between 1 and 31
    if [[ $day -lt 1 || $day -gt 31 ]]; then
        echo "Can't parse the date!"
        exit 1
    fi
    # check if the month is a number between 1 and 12
    if [[ $month -lt 1 || $month -gt 12 ]]; then
        echo "Can't parse the date!"
        exit 1
    fi
    # check if the year is a number between 1 and 9999
    if [[ $year -lt 1900 || $year -gt 9999 ]]; then
        echo "Can't parse the date!"
        exit 1
    fi
}


main() {

    if [ $# -ne 1 ]; then
        echo "You have to provide the new date in a format DD-MM-YYYY"
        exit 1
    fi

    date="$1"
    validate_date "$date"
    day_string=$(day_string_converter "$day" "$month" "$year")
    month_string=$(month_string_converter "$month")
    time_string=$(random_time)

    LC_ALL=C GIT_COMMITTER_DATE="$day_string $month_string $day $time_string $year +0100" git commit --amend --no-edit --date "$day_string $month_string $day $time_string $year +0100"
}

main "$@"
