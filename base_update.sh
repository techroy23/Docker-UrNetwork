#!/bin/bash

# Function to download release tar.gz from GitHub API
Download_API() {
    local repo="$1"   # e.g. "connect" or "build"
    local suffix="$2" # e.g. "stable" or "nightly"
    local API="https://api.github.com/repos/urnetwork/${repo}/releases/latest"
    local release_url=$(curl -s "$API" | jq -r '.url')
    echo "${suffix^} release URL: $release_url"
    local release_json=$(curl -s "$release_url")
    local download_url=$(echo "$release_json" | jq -r '.assets[] | select(.name | startswith("urnetwork-provider-")) | .browser_download_url')
    echo "Download URL: $download_url"
    local filename=$(basename "$download_url")
    echo "Filename: $filename"
    curl -L -k -A "Mozilla/5.0" -o "$filename" "$download_url"
    echo "Downloaded: $filename"
    echo "$filename $suffix" >> download_list.txt
}

# Function to extract provider binaries from tar.gz
Extract_Providers() {
    local filename="$1"
    local suffix="$2"
    mkdir -p ./app
    tar --warning=no-unknown-keyword --extract --file="$filename" --strip-components=2 "linux/amd64/provider" -O > "./app/urnetwork_amd64_${suffix}"
    chmod +x "./app/urnetwork_amd64_${suffix}"
    echo "Extracted amd64 provider → ./app/urnetwork_amd64_${suffix}"
    tar --warning=no-unknown-keyword --extract --file="$filename" --strip-components=2 "linux/arm64/provider" -O > "./app/urnetwork_arm64_${suffix}"
    chmod +x "./app/urnetwork_arm64_${suffix}"
    echo "Extracted arm64 provider to ./app/urnetwork_arm64_${suffix}"
    rm -f "$filename"
    echo "Deleted archive: $filename"
}

# --- Phase 1: Download all ---
Download_API "connect" "stable"
Download_API "build" "nightly"

# --- Phase 2: Extract all ---
while read -r filename suffix; do
    Extract_Providers "$filename" "$suffix"
done < download_list.txt

# Cleanup list
rm -f download_list.txt
