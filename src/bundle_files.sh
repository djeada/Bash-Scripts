#!/usr/bin/env bash

main() {
    local bundle_files_path="$1"
    local bundle_files_list="$2"
    local bundle_files_destination="$3"
    local bundle_files_source="$4"

    if [[ ! -d "$bundle_files_path" ]]; then
        mkdir -p "$bundle_files_path"
    fi

    if [[ ! -f "$bundle_files_list" ]]; then
        touch "$bundle_files_list"
    fi

    if [[ ! -d "$bundle_files_destination" ]]; then
        mkdir -p "$bundle_files_destination"
    fi

    if [[ ! -d "$bundle_files_source" ]]; then
        mkdir -p "$bundle_files_source"
    fi

    echo "Bundling files..."

    while IFS='' read -r line || [[ -n "$line" ]]; do
        local bundle_file_source="$bundle_files_source/$line"
        local bundle_file_destination="$bundle_files_destination/$line"

        if [[ -f "$bundle_file_source" ]]; then
            cp "$bundle_file_source" "$bundle_file_destination"
        fi
    done < "$bundle_files_list"

    echo "Done bundling files."

}

}

main "$@"
