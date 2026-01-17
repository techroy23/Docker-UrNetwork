#!/bin/sh
# URNetwork Provider Entrypoint Script
# ------------------------------------
# This script bootstraps the URNetwork provider inside a container.
# Responsibilities:
#   - Validate environment and credentials
#   - Configure proxy if provided
#   - Detect system architecture
#   - Optionally check public IP
#   - Start vnStat monitoring and lightweight HTTP server
#   - Authenticate and obtain JWT
#   - Manage provider lifecycle (restart on crash)
#   - Check for provider updates from GitHub releases
#   - Run a time-based watcher to auto-update daily at $UPDATE_TIME

# Exit immediately if any command fails
set -e

# === Configuration Variables ===
APP_DIR="/app"
JWT_FILE="/root/.urnetwork/jwt"
ENABLE_VNSTAT="${ENABLE_VNSTAT:-true}"
ENABLE_IP_CHECKER="${ENABLE_IP_CHECKER:-false}"
IP_CHECKER_URL="https://raw.githubusercontent.com/techroy23/IP-Checker/refs/heads/main/app.sh"
API_URL="https://api.github.com/repos/urnetwork/build/releases/latest"
VERSION_FILE="$APP_DIR/version.txt"
TMP_DIR="/tmp/urn_update"
UPDATE_TIME="12:00"

# === Logging Helper ===
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') >>> An2Kin >>> $*"
}

# === Directory Validation ===
func_check_dir() {
    [ -d "$APP_DIR" ] || {
        log "[ERROR] APP_DIR '$APP_DIR' does not exist." >&2
        exit 1
    }
    cd "$APP_DIR" || {
        log "[ERROR] cannot cd to '$APP_DIR'." >&2
        exit 1
    }
}

# === Credential Validation ===
func_check_credentials() {
    if [ -z "$USER_AUTH" ] || [ -z "$PASSWORD" ]; then
        log "ERROR: USER_AUTH or PASSWORD not set"
        log "Please provide both -e USER_AUTH and -e PASSWORD"
        exit 1
    else
        log "Credentials found"
    fi
}

# === Proxy Setup ===
func_check_proxy() {
    log "Checking proxy configuration"
    ls -la ~/.urnetwork/ 2>/dev/null || log "~/.urnetwork/ not found"
    rm -f ~/.urnetwork/proxy
    if [ -f "/app/proxy.txt" ]; then
        log "Proxy.txt found; adding proxy"
        "$APP_DIR/provider" proxy add --proxy_file="/app/proxy.txt"
    else
        log "No proxy.txt found; skipping proxy add"
    fi
}

# === Architecture Detection ===
func_get_architecture() {
    case "$(uname -m)" in
      x86_64)  A_SYS_ARCH=amd64  ;;
      aarch64) A_SYS_ARCH=arm64  ;;
      *)
        log "[ERROR] Unsupported arch $(uname -m)" >&2
        exit 1
        ;;
    esac
}

# === Public IP Checker ===
func_get_ip() {
  if [ "$ENABLE_IP_CHECKER" = "true" ]; then
    log "Checking current public IP..."
    if curl -fsSL "$IP_CHECKER_URL" | sh; then
      log "IP checker script ran successfully"
    else
      log "WARNING: Could not fetch or execute IP checker script"
    fi
  else
    log "IP checker disabled"
  fi
}

# === vnStat Monitoring Setup ===
func_start_vnstat() {
    VNSTAT_LC="$(printf '%s' "$ENABLE_VNSTAT" | tr '[:upper:]' '[:lower:]')"
    if [ "$VNSTAT_LC" = "true" ]; then
        if [ -f /var/lib/vnstat/vnstat.db ]; then
            log "vnStat DB already exists (SQLite backend)"
        elif [ -f /var/lib/vnstat/.config ]; then
            log "vnStat DB already exists (binary backend)"
        else
            log "Initializing vnStat database"
            vnstatd --initdb
        fi
        vnstatd -d --alwaysadd >/dev/null 2>&1
        log "vnstatd started"
        httpd -f -p 8080 -h /app &
        log "HTTP server started on container port 8080"
    else
        log "VNSTAT disabled ..."
    fi
}

# === Provider Update Check ===
func_check_update() {
    if [ -f "$VERSION_FILE" ]; then
        CURRENT_VERSION="$(cat "$VERSION_FILE")"
    else
        CURRENT_VERSION=""
    fi
    log "Current provider version: ${CURRENT_VERSION:-none}"
    mkdir -p "$TMP_DIR"
    RESP_FILE="$TMP_DIR/release.json"
    HTTP_CODE="$(curl -sL -w '%{http_code}' -o "$RESP_FILE" "$API_URL")"
    RELEASE_JSON="$(cat "$RESP_FILE")"
    DOWNLOAD_URL="$(printf '%s\n' "$RELEASE_JSON" \
      | grep '"browser_download_url"' \
      | grep 'urnetwork-provider-.*\.tar\.gz' \
      | sed -E 's/.*"([^"]+)".*/\1/' \
      | head -n1)"
      log "$DOWNLOAD_URL"
    [ -n "$DOWNLOAD_URL" ] || {
        log "[ERROR] No .tar.gz URL in GitHub response." >&2
        log "[ERROR] HTTP status: $HTTP_CODE" >&2
        log "[ERROR] Raw response:" >&2
        log "$RELEASE_JSON" | jq . >&2
        return 0
    }

    LATEST_VERSION="$(printf '%s\n' "$DOWNLOAD_URL" \
      | sed -E 's#.*/download/v([^/]+)/.*#\1#')"
    log "Latest provider version: $LATEST_VERSION"
    if [ "$LATEST_VERSION" = "$CURRENT_VERSION" ]; then
        log "Already at latest provider version; skipping."
        return 0
    else
        log "Updating provider from ( $CURRENT_VERSION ) → ( $LATEST_VERSION )"
        pkill -x "urnetwork_${A_SYS_ARCH}_nightly" 2>/dev/null || log "No provider to kill"
        mkdir -p "$TMP_DIR"
        ARCHIVE="$TMP_DIR/urnetwork-provider_${LATEST_VERSION}.tar.gz"
        curl -sL "$DOWNLOAD_URL" -o "$ARCHIVE"
        tar -xzf "$ARCHIVE" -C "$TMP_DIR" "linux/${A_SYS_ARCH}/provider" > /dev/null 2>&1
        mv "$TMP_DIR/linux/${A_SYS_ARCH}/provider" "$APP_DIR/urnetwork_${A_SYS_ARCH}_nightly"
        echo "$LATEST_VERSION" > "$VERSION_FILE"
        rm -f "$ARCHIVE"
        log "Update provider complete"
    fi
}

# === Authentication (JWT) ===
func_do_login() {
    rm -f "$JWT_FILE"
    log "Removed existing JWT (if any)"
    log "Sleeping 15s before obtaining new JWT..."
    sleep 15
    PROVIDER_BIN="$APP_DIR/urnetwork_${A_SYS_ARCH}_nightly"
    log "Obtaining new JWT…"
    "$PROVIDER_BIN" auth --user_auth="$USER_AUTH" --password="$PASSWORD" -f \
    || { log "auth failed" >&2; exit 1; }
    sleep 5
    [ -s "$JWT_FILE" ] || { log "no JWT file after auth" >&2; exit 1; }
    log "obtained JWT"
}

# === Provider Lifecycle Management ===
func_start_provider(){
    failures=0
    while :; do
        log "Starting provider (attempt #$((failures+1)))"
        PROVIDER_BIN="$APP_DIR/urnetwork_${A_SYS_ARCH}_nightly"
		BIN_VER="$($PROVIDER_BIN --version)"
		log "Running UrNetwork build v${BIN_VER}"
        "$PROVIDER_BIN" provide
        code=$?
        if [ "$code" -eq 0 ]; then
            log "provider exited cleanly."
            break
        fi
        failures=$((failures+1))
        log "provider crashed (#$failures; code=$code)"
        if [ "$failures" -ge 3 ]; then
            log "too many crashes; clearing JWT and reauthenticating"
            rm -f "$JWT_FILE"
            func_check_credentials
            failures=0
        fi
        log "Waiting 60s before retry"
        sleep 60
    done
}

# === Bootstrap Sequence ===
func_bootstrap() {
    sh /app/urnetwork_ipinfo.sh
	func_check_dir
	func_check_credentials
	func_check_proxy
	func_get_architecture
    func_get_ip
    func_start_vnstat
	func_check_update
    (
      while :; do
        NOW="$(TZ='Asia/Manila' date +%H:%M)"
        if [ "$NOW" = "$UPDATE_TIME" ]; then
            log "Watcher: hit $UPDATE_TIME, updating"
            func_check_update
            if ! ps aux | grep -q '[u]rnetwork_${A_SYS_ARCH}_'; then
                log "Provider not running; launching now"
                func_do_login
                func_start_provider
            else
                log "Provider already running; skipping restart"
            fi
            sleep 60
        fi
        sleep 30
      done
    ) &
    WATCHER_PID=$!
    log "Time‐watcher PID is $WATCHER_PID"
    func_do_login
    func_start_provider
}

# === Main Entrypoint ===
main() {
    func_bootstrap
}

main "$@"
