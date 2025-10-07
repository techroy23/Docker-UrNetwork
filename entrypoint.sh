#!/bin/sh
 
set -e

ENABLE_IP_CHECKER="${ENABLE_IP_CHECKER:-false}"
API_URL="https://api.github.com/repos/urnetwork/build/releases/latest"
IP_CHECKER_URL="https://raw.githubusercontent.com/techroy23/IP-Checker/refs/heads/main/app.sh"
APP_DIR="/app"
VERSION_FILE="$APP_DIR/version.txt"
JWT_FILE="/root/.urnetwork/jwt"
TMP_DIR="/tmp/urn_update"
UPDATE_TIME="12:00"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $*"
}

ensure_app_dir() {
    [ -d "$APP_DIR" ] || {
        echo ">>> An2Kin >>> Error: APP_DIR '$APP_DIR' does not exist." >&2
        exit 1
    }
    cd "$APP_DIR" || {
        echo ">>> An2Kin >>> Error: cannot cd to '$APP_DIR'." >&2
        exit 1
    }
}

get_arch() {
    case "$(uname -m)" in
      x86_64)  URN_ARCH=amd64  ;;
      aarch64) URN_ARCH=arm64  ;;
      *)
        echo ">>> An2Kin >>> Unsupported arch $(uname -m)" >&2
        exit 1
        ;;
    esac
}

check_and_update() {
    get_arch
    if [ -f "$VERSION_FILE" ]; then
        CURRENT_VERSION="$(cat "$VERSION_FILE")"
    else
        CURRENT_VERSION=""
    fi
    echo ">>> An2Kin >>> Current provider version: ${CURRENT_VERSION:-none}"
    RELEASE_JSON="$(curl -sL "$API_URL")"
    DOWNLOAD_URL="$(printf '%s\n' "$RELEASE_JSON" \
      | grep '"browser_download_url"' \
      | grep '\.tar\.gz' \
      | sed -E 's/.*"([^"]+)".*/\1/' \
      | head -n1)"
    [ -n "$DOWNLOAD_URL" ] || {
        echo ">>> An2Kin >>> No .tar.gz URL in GitHub response." >&2
        return 1
    }

    LATEST_VERSION="$(printf '%s\n' "$DOWNLOAD_URL" \
      | sed -E 's#.*/download/v([^/]+)/.*#\1#')"
    echo ">>> An2Kin >>> Latest provider version: $LATEST_VERSION"
    if [ "$LATEST_VERSION" = "$CURRENT_VERSION" ]; then
        echo ">>> An2Kin >>> Already at latest provider version; skipping."
        return 0
    else
        echo ">>> An2Kin >>> Updating provider from ( $CURRENT_VERSION ) → ( $LATEST_VERSION )"
        pkill -x provider 2>/dev/null || echo ">>> An2Kin >>> No provider to kill"
        mkdir -p "$TMP_DIR"
        ARCHIVE="$TMP_DIR/urnetwork-provider_${LATEST_VERSION}.tar.gz"
        curl -sL "$DOWNLOAD_URL" -o "$ARCHIVE"
        tar -xzf "$ARCHIVE" -C "$TMP_DIR" "linux/$URN_ARCH/provider" > /dev/null 2>&1
        mv "$TMP_DIR/linux/$URN_ARCH/provider" "$APP_DIR/provider"
        echo "$LATEST_VERSION" > "$VERSION_FILE"
        echo ">>> An2Kin >>> Update provider complete"
    fi
}

login() {
    rm -f ~/.urnetwork/jwt
    echo ">>> An2Kin >>> Removed existing JWT (if any)"
    echo ">>> An2Kin >>> Sleeping 15s before obtaining new JWT..."
    sleep 15

    echo ">>> An2Kin >>> Obtaining new JWT…"
    "$APP_DIR/provider" auth --user_auth="$USER_AUTH" --password="$PASSWORD" -f \
    || { echo ">>> An2Kin >>> auth failed" >&2; exit 1; }

    sleep 5

    [ -s "$JWT_FILE" ] || { echo ">>> An2Kin >>> no JWT file after auth" >&2; exit 1; }
    echo ">>> An2Kin >>> obtained JWT"
}

check_proxy() {
    echo ">>> An2Kin >>> Checking proxy configuration"
    ls -la ~/.urnetwork/ 2>/dev/null || echo ">>> An2Kin >>> ~/.urnetwork/ not found"
    rm -f ~/.urnetwork/proxy
    if [ -f "/app/proxy.txt" ]; then
        echo ">>> An2Kin >>> proxy.txt found; adding proxy"
        "$APP_DIR/provider" proxy add --proxy_file="/app/proxy.txt"
    else
        echo ">>> An2Kin >>> No proxy.txt found; skipping proxy add"
    fi
}

main_provider(){
    failures=0
    while :; do
        ensure_app_dir
        echo ">>> An2Kin >>> Starting provider (attempt #$((failures+1)))"
        "$APP_DIR/provider" provide
        code=$?
        if [ "$code" -eq 0 ]; then
            echo ">>> An2Kin >>> provider exited cleanly."
            break
        fi
        failures=$((failures+1))
        echo ">>> An2Kin >>> provider crashed (#$failures; code=$code)"
        if [ "$failures" -ge 3 ]; then
            echo ">>> An2Kin >>> too many crashes; clearing JWT and reauthenticating"
            rm -f "$JWT_FILE"
            check_credentials
            failures=0
        fi
        echo ">>> An2Kin >>> Waiting 60s before retry"
        sleep 60
    done
}

check_ip() {
  if [ "$ENABLE_IP_CHECKER" = "true" ]; then
    log " >>> An2Kin >>> Checking current public IP..."
    if curl -fsSL "$IP_CHECKER_URL" | sh; then
      log " >>> An2Kin >>> IP checker script ran successfully"
    else
      log " >>> An2Kin >>> WARNING: Could not fetch or execute IP checker script"
    fi
  else
    log " >>> An2Kin >>> IP checker disabled (ENABLE_IP_CHECKER=$ENABLE_IP_CHECKER)"
  fi
}

runner() {
    echo ">>> An2Kin >>> Script version: v10.7.2025"
    sh /app/ipinfo.sh
    check_ip
    if [ -f /var/lib/vnstat/vnstat.db ]; then
        echo ">>> An2Kin >>> vnStat DB already exists (SQLite backend)"
    elif [ -f /var/lib/vnstat/.config ]; then
        echo ">>> An2Kin >>> vnStat DB already exists (binary backend)"
    else
        echo ">>> An2Kin >>> Initializing vnStat database"
        vnstatd --initdb
    fi
    vnstatd -d --alwaysadd >/dev/null 2>&1
    echo ">>> An2Kin >>> vnstatd started"
    httpd -f -p 8080 -h /app &
    echo ">>> An2Kin >>> HTTP server started on container port 8080"
    ensure_app_dir
    check_and_update
    check_proxy
    (
      while :; do
        NOW="$(TZ='Asia/Manila' date +%H:%M)"
        if [ "$NOW" = "$UPDATE_TIME" ]; then
            echo ">>> An2Kin >>> watcher: hit $UPDATE_TIME, updating"
            check_and_update
            if ! ps aux | grep -q '[p]rovider provide'; then
                echo ">>> An2Kin >>> provider not running; launching now"
                login
                main_provider
            else
                echo ">>> An2Kin >>> provider already running; skipping restart"
            fi
            sleep 60
        fi
        sleep 30
      done
    ) &
    WATCHER_PID=$!
    echo ">>> An2Kin >>> Time‐watcher PID is $WATCHER_PID"
    login
    main_provider
}

main() {
    runner
}

main "$@"
