#!/usr/bin/env bash

check_dependencies() {
    local dependencies=("youtube-dl" "ffmpeg")
    for dependency in "${dependencies[@]}"; do
        if ! command -v "$dependency" >/dev/null 2>&1; then
            echo "Error: '$dependency' is not installed."
            return 1
        fi
    done
    return 0
}


try_to_install_dependencies() {
    local dependencies=("youtube-dl" "ffmpeg")

    if [ -f /etc/os-release ]; then
        if grep -q "debian" /etc/os-release; then
            local command_to_instal="apt install"
        elif grep -q "arch" /etc/os-release; then
            local command_to_instal="pacman -S"
        else
            echo "Error: Unknown OS"
            return 1
        fi
    fi

    for dependency in "${dependencies[@]}"; do
        if ! command -v "$dependency" >/dev/null 2>&1; then
            echo "Trying to install '$dependency'."
            sudo $command_to_instal "$dependency"
        fi
    done
}

download_video() {
    local url="$1"
    local output_file="$2"
    youtube-dl -f bestaudio -o "$output_file" "$url"
}


convert_video_to_mp3() {
    local input_file="$1"
    local output_file="${input_file%.*}.mp3"
    ffmpeg -i "$input_file" -vn -ab 128k "$output_file"
    rm "$input_file"
}


main() {
    if [ $# -lt 1 ]; then
        echo "Usage: youtube_to_mp3.sh [url] <output_file>"
        return
    fi

    if ! check_dependencies; then
        try_to_install_dependencies
        if ! check_dependencies; then
            echo "Error: Dependencies not installed."
            return 1
        fi
    fi

    local url="$1"

    if [ $# -eq 2 ]; then
        output_file="$2"
    else
        output_file=$(youtube-dl --get-title "$url")
        #convert spaces to underscores and make lowercase
        output_file=$(echo "$output_file" | tr ' ' '_' | tr '[:upper:]' '[:lower:]')
    fi

    download_video "$url" "$output_file"
    convert_video_to_mp3 "$output_file"
}


main "$@"
