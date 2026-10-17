#!/bin/bash
set -Eeuo pipefail

# Image build helper: downloads the latest UrNetwork provider from the
# urnetwork/build (nightly) releases and unpacks both architectures into /app.

API_URL="https://api.github.com/repos/urnetwork/build/releases"
MAX_PAGES=10
SUFFIX="nightly"

# === Logging Helper ===
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') >>> UrNetwork >>> $*"
}

# === Trap errors and print the failing line + function ===
trap 'log "[ERROR] Failure at line $LINENO in function $FUNCNAME"; exit 1' ERR

log "[INFO] Starting provider update process"

# === Find and download the latest release that ships the provider ===
Download_Provider() {
    local page=1
    local download_url=""
    local tag_name=""

    while [[ $page -le $MAX_PAGES ]]; do
      local releases_json
      releases_json=$(curl -s "$API_URL?page=$page&per_page=10")

      local count
      count=$(echo "$releases_json" | jq 'length')

      if [[ "$count" -eq 0 ]]; then
        log "[WARN] No more releases found after $page pages"
        break
      fi

      local i=0
      while [[ $i -lt $count ]]; do
        local release_url
        release_url=$(echo "$releases_json" | jq -r ".[$i].url")
        tag_name=$(echo "$releases_json" | jq -r ".[$i].tag_name")

        log "[INFO] Checking release: $tag_name"

        local release_json
        release_json=$(curl -s "$release_url")

        download_url=$(echo "$release_json" | jq -r '.assets[] | select(.name | startswith("urnetwork-provider-")) | .browser_download_url')

        if [[ -n "$download_url" ]]; then
          log "[INFO] Found provider asset in $tag_name"
          log "[INFO] Download URL: $download_url"
          break 2
        fi

        i=$((i + 1))
      done

      page=$((page + 1))
    done

    if [[ -z "$download_url" ]]; then
      log "[WARN] No urnetwork-provider-*.tar.gz asset found in any release"
      return 1
    fi

    local filename
    filename=$(basename "$download_url")
    log "[INFO] Downloading $filename..."
    curl -L -k -A "Mozilla/5.0" -o "$filename" "$download_url"
    log "[INFO] Downloaded: $filename"

    Extract_Providers "$filename" "$SUFFIX"
    rm -f "$filename" || true
    log "[INFO] Deleted archive: $filename"

    # Record the version baked into the image so containers only download a
    # new provider when a newer release actually exists.
    printf '%s\n' "$(echo "$tag_name" | sed 's/^v//')" > /app/version.txt
    log "[INFO] Recorded provider version in /app/version.txt"
}

# === Extract provider binaries from tar.gz ===
Extract_Providers() {
    local filename="$1"
    local suffix="$2"

    log "[INFO] Extract_Providers → File: $filename | Suffix: $suffix"

    mkdir -p /app

    log "[INFO] Extracting amd64 provider..."
    tar --warning=no-unknown-keyword --extract --file="$filename" --strip-components=2 "linux/amd64/provider" -O > "/app/urnetwork_amd64_${suffix}"
    chmod +x "/app/urnetwork_amd64_${suffix}"
    log "[INFO] Extracted amd64 → /app/urnetwork_amd64_${suffix}"

    log "[INFO] Extracting arm64 provider..."
    tar --warning=no-unknown-keyword --extract --file="$filename" --strip-components=2 "linux/arm64/provider" -O > "/app/urnetwork_arm64_${suffix}"
    chmod +x "/app/urnetwork_arm64_${suffix}"
    log "[INFO] Extracted arm64 → /app/urnetwork_arm64_${suffix}"
}

Download_Provider
log "[INFO] Provider update process completed successfully"
