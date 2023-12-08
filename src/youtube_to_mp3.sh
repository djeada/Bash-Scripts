#!/usr/bin/env bash

check_dependencies() {
    local dependencies=("yt-dlp" "ffmpeg")
    for dependency in "${dependencies[@]}"; do
        if ! which "$dependency" >/dev/null 2>&1; then
            echo "Error: '$dependency' is not installed."
            return 1
        fi
    done
    return 0
}

try_to_install_dependencies() {
    local dependencies=("yt-dlp" "ffmpeg")

    if [ -f /etc/os-release ]; then
        if grep -q "debian" /etc/os-release; then
            local command_to_install="apt install"
        elif grep -q "arch" /etc/os-release; then
            local command_to_install="pacman -S"
        else
            echo "Error: Unknown OS"
            return 1
        fi
    else
        echo "Error: /etc/os-release not found"
        return 1
    fi

    for dependency in "${dependencies[@]}"; do
        if ! which "$dependency" >/dev/null 2>&1; then
            echo "Trying to install '$dependency'."
            eval sudo $command_to_install "$dependency"
        fi
    done
}

download_video() {
    local url="$1"
    local output_file="$2"
    echo "Attempting to download video from '$url'"
    yt-dlp -f bestaudio -o "$output_file" "$url"
    echo "Saving video to '$output_file'"
}

convert_video_to_mp3() {
    local input_file="$1"
    local output_file="${input_file%.*}.mp3"
    echo "Converting video to mp3"
    ffmpeg -i "$input_file" -vn -ab 128k "$output_file"
    echo "Audio file saved to '$output_file'"
    rm "$input_file"
    echo "Video file deleted"
}

download_video_and_convert_to_mp3() {
    local url="$1"
    local output_file
    if [ -z "$2" ]; then
        output_file=$(yt-dlp --get-title "$url")
        output_file=$(echo "$output_file" | tr ' ' '_' | tr '[:upper:]' '[:lower:]')
    else
        output_file="$2"
    fi

    download_video "$url" "$output_file"
    convert_video_to_mp3 "$output_file"
}

read_playlist_to_array() {
    local url="$1"
    local temp_file
    temp_file="$(mktemp)"
    yt-dlp -j --flat-playlist --skip-download "$url" | jq -r '.id' | sed 's_^_https://youtu.be/_' > "$temp_file"
    IFS=$'\n' read -d '' -r -a all_videos_urls < "$temp_file"
    unset IFS
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
    read_playlist_to_array "$url"

    if [ "${#all_videos_urls[@]}" -eq 0 ]; then
        echo "No videos found in the playlist."
        return 1
    fi

    if [ "${#all_videos_urls[@]}" -gt "1" ]; then
        echo "Downloading playlist..."
        for video_url in "${all_videos_urls[@]}"; do
            download_video_and_convert_to_mp3 "$video_url"
        done
    else
        download_video_and_convert_to_mp3 "$url" "$2"
    fi
}

main "$@"
