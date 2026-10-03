#!/usr/bin/env bash

# Script Name: christmas_tree.sh
# Description: Prints a Christmas tree of a given height and character to the standard output.
# Usage: christmas_tree.sh height character
#        height - the height of the Christmas tree.
#        character - the character to be used to draw the Christmas tree.
# Example: ./christmas_tree.sh 10 '*'

draw_level() {
    local level_size=$1
    local character=$2
    local offset=$3 # extra indentation so every level is centred on the trunk

    for ((i = 0; i < level_size; i++)); do
        printf "%*s" $((offset + level_size - i)) "" # print spaces
        printf '%*s\n' $((2 * i + 1)) "" | tr ' ' "$character" # print characters
    done
}

draw_trunk() {
    local tree_height=$1
    local character=$2

    printf "%*s%s\n" "$tree_height" "" "$character"
}

draw_christmas_tree() {
    local tree_height=$1
    local character=$2

    for ((i = 1; i <= tree_height; i++)); do
        draw_level "$i" "$character" $((tree_height - i))
    done
    draw_trunk "$tree_height" "$character" # print the trunk
}

main() {
    if [ $# -ne 2 ]; then
        echo "Must provide exactly two arguments: tree height and character to draw the tree!" >&2
        exit 1
    fi

    re='^[1-9][0-9]*$'
    if ! [[ $1 =~ $re ]]; then
        echo "$1 is not a positive integer!" >&2
        exit 1
    fi

    if [ ${#2} -ne 1 ]; then
        echo "The tree must be drawn with exactly one character!" >&2
        exit 1
    fi

    draw_christmas_tree "$1" "$2"
}

main "$@"

