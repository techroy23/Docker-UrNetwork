#!/bin/bash
set -Eeuo pipefail

# Trap errors and print the failing line + function
trap 'echo "[ERROR] Failure at line $LINENO in function $FUNCNAME"; exit 1' ERR

echo "[INFO] Starting provider update process"

# Function to download release tar.gz from GitHub API
Download_API() {
    local repo="$1"   # e.g. "connect" or "build"
    local suffix="$2" # e.g. "stable" or "nightly"

    echo "[INFO] Download_API → Repo: $repo | Suffix: $suffix"

    local API="https://api.github.com/repos/urnetwork/${repo}/releases/latest"
    local release_url
    release_url=$(curl -s "$API" | jq -r '.url')
    echo "[INFO] Release URL: $release_url"

    local release_json
    release_json=$(curl -s "$release_url")

    local download_url
    download_url=$(echo "$release_json" | jq -r '.assets[] | select(.name | startswith("urnetwork-provider-")) | .browser_download_url')
    echo "[INFO] Download URL: $download_url"

    local filename
    filename=$(basename "$download_url")
    echo "[INFO] Filename: $filename"

    echo "[INFO] Downloading $filename..."
    curl -L -k -A "Mozilla/5.0" -o "$filename" "$download_url"
    echo "[INFO] Downloaded: $filename"

    echo "$filename $suffix" >> download_list.txt
}

# Function to extract provider binaries from tar.gz
Extract_Providers() {
    local filename="$1"
    local suffix="$2"

    echo "[INFO] Extract_Providers → File: $filename | Suffix: $suffix"

    mkdir -p /app

    echo "[INFO] Extracting amd64 provider..."
    tar --warning=no-unknown-keyword --extract --file="$filename" --strip-components=2 "linux/amd64/provider" -O > "/app/urnetwork_amd64_${suffix}"
    chmod +x "/app/urnetwork_amd64_${suffix}"
    echo "[INFO] Extracted amd64 → /app/urnetwork_amd64_${suffix}"

    echo "[INFO] Extracting arm64 provider..."
    tar --warning=no-unknown-keyword --extract --file="$filename" --strip-components=2 "linux/arm64/provider" -O > "/app/urnetwork_arm64_${suffix}"
    chmod +x "/app/urnetwork_arm64_${suffix}"
    echo "[INFO] Extracted arm64 → /app/urnetwork_arm64_${suffix}"

    rm -f "$filename"
    echo "[INFO] Deleted archive: $filename"
}

# --- Phase 1: Download all ---
echo "[INFO] Phase 1: Download releases"
Download_API "connect" "stable"
Download_API "build" "nightly"

# --- Phase 2: Extract all ---
echo "[INFO] Phase 2: Extract providers"
while read -r filename suffix; do
    Extract_Providers "$filename" "$suffix"
done < download_list.txt

# Cleanup list
rm -f download_list.txt
echo "[INFO] Cleaned up download_list.txt"

echo "[INFO] Provider update process completed successfully"
