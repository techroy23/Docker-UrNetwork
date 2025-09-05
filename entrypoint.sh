#!/bin/sh

set -e

API_URL="https://api.github.com/repos/urnetwork/build/releases/latest"
APP_DIR="/app"
VERSION_FILE="$APP_DIR/version.txt"
JWT_FILE="/root/.urnetwork/jwt"
TMP_DIR="/tmp/urn_update"
UPDATE_TIME="12:00"

ensure_app_dir() {
    [ -d "$APP_DIR" ] || {
        echo " "
        echo " >>> An2Kin >>> Error: APP_DIR '$APP_DIR' does not exist." >&2
        echo " "
        exit 1
    }
    cd "$APP_DIR" || {
        echo " "
        echo " >>> An2Kin >>> Error: cannot cd to '$APP_DIR'." >&2
        echo " "
        exit 1
    }
}

get_arch() {
    case "$(uname -m)" in
      x86_64)  URN_ARCH=amd64  ;;
      aarch64) URN_ARCH=arm64  ;;
      *)
        echo " "
        echo " >>> An2Kin >>> Unsupported arch $(uname -m)" >&2
        echo " "
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
    echo " "
    echo " >>> An2Kin >>> Current version: ${CURRENT_VERSION:-none}"
    echo " "
    RELEASE_JSON="$(curl -sL "$API_URL")"
    DOWNLOAD_URL="$(printf '%s\n' "$RELEASE_JSON" \
      | grep '"browser_download_url"' \
      | grep '\.tar\.gz' \
      | sed -E 's/.*"([^"]+)".*/\1/' \
      | head -n1)"
    [ -n "$DOWNLOAD_URL" ] || {
        echo " "
        echo " >>> An2Kin >>> No .tar.gz URL in GitHub response." >&2
        echo " "
        return 1
    }

    LATEST_VERSION="$(printf '%s\n' "$DOWNLOAD_URL" \
      | sed -E 's#.*/download/v([^/]+)/.*#\1#')"
    echo " "
    echo " >>> An2Kin >>> Latest version: $LATEST_VERSION"
    echo " "
    if [ "$LATEST_VERSION" = "$CURRENT_VERSION" ]; then
        echo " "
        echo " >>> An2Kin >>> Already at latest version; skipping."
        echo " "
        return 0
    else
        echo " "
        echo " >>> An2Kin >>> Updating from ( $CURRENT_VERSION ) → ( $LATEST_VERSION )"
        echo " "
        pkill -x provider 2>/dev/null || echo " >>> An2Kin >>> No provider to kill"
        mkdir -p "$TMP_DIR"
        ARCHIVE="$TMP_DIR/urnetwork-provider_${LATEST_VERSION}.tar.gz"
        curl -sL "$DOWNLOAD_URL" -o "$ARCHIVE"
        tar -xzf "$ARCHIVE" -C "$TMP_DIR" "linux/$URN_ARCH/provider" > /dev/null 2>&1
        mv "$TMP_DIR/linux/$URN_ARCH/provider" "$APP_DIR/provider"
        echo "$LATEST_VERSION" > "$VERSION_FILE"
        echo " "
        echo " >>> An2Kin >>> Update complete"
        echo " "
    fi
}

login() {
    rm -f ~/.urnetwork/jwt
    echo " "
    echo " >>> An2Kin >>> Removed existing JWT (if any)"
    echo " "

    echo " "
    echo " >>> An2Kin >>> Sleeping 15s before obtaining new JWT..."
    echo " "
    sleep 15

    echo " "
    echo " >>> An2Kin >>> Obtaining new JWT…"
    echo " "
    "$APP_DIR/provider" auth --user_auth="$USER_AUTH" --password="$PASSWORD" -f \
    || { echo "  >>> An2Kin >>> auth failed" >&2; exit 1; }

    sleep 5

    [ -s "$JWT_FILE" ] || { echo "  >>> An2Kin >>> no JWT file after auth" >&2; exit 1; }
    echo " "
    echo " >>> An2Kin >>> obtained JWT"
    echo " "
}

check_proxy() {
    echo " "
    echo " >>> An2Kin >>> Checking proxy configuration"
    echo " "
    ls -la ~/.urnetwork/ 2>/dev/null || echo " >>> An2Kin >>> ~/.urnetwork/ not found"
    rm -f ~/.urnetwork/proxy
    if [ -f "/app/proxy.txt" ]; then
        echo " "
        echo " >>> An2Kin >>> proxy.txt found; adding proxy"
        echo " "
        "$APP_DIR/provider" proxy add --proxy_file="/app/proxy.txt"
    else
        echo " "
        echo " >>> An2Kin >>> No proxy.txt found; skipping proxy add"
        echo " "
    fi
}

main_provider(){
    failures=0
    while :; do
        ensure_app_dir
        echo " "
        echo " >>> An2Kin >>> Starting provider (attempt #$((failures+1)))"
        echo " "
        "$APP_DIR/provider" provide
        code=$?
        if [ "$code" -eq 0 ]; then
            echo " "
            echo " >>> An2Kin >>> provider exited cleanly."
            echo " "
            break
        fi
        failures=$((failures+1))
        echo " "
        echo " >>> An2Kin >>> provider crashed (#$failures; code=$code)"
        echo " "
        if [ "$failures" -ge 3 ]; then
            echo " "
            echo " >>> An2Kin >>> too many crashes; clearing JWT and reauthenticating"
            echo " "
            rm -f "$JWT_FILE"
            check_credentials
            failures=0
        fi
        echo " "
        echo " >>> An2Kin >>> Waiting 60s before retry"
        echo " "
        sleep 60
    done
}

runner() {
    echo " "
    echo " >>> An2Kin >>> Script version: v9.6.2025"
    echo " "
    sh /app/ipinfo.sh
    ensure_app_dir
    check_and_update
    check_proxy
    (
      while :; do
        NOW="$(TZ='Asia/Manila' date +%H:%M)"
        if [ "$NOW" = "$UPDATE_TIME" ]; then
            echo " "
            echo " >>> An2Kin >>> watcher: hit $UPDATE_TIME, updating"
            echo " "
            check_and_update
            if ! ps aux | grep -q '[p]rovider provide'; then
                echo " "
                echo ">>> An2Kin >>> provider not running; launching now"
                echo " "
                login
                main_provider
            else
                echo " "
                echo ">>> An2Kin >>> provider already running; skipping restart"
                echo " "
            fi
            sleep 60
        fi
        sleep 30
      done
    ) &
    WATCHER_PID=$!
    echo " "
    echo " >>> An2Kin >>> Time‐watcher PID is $WATCHER_PID"
    echo " "
    login
    main_provider
}

main() {
    runner
}

main "$@"
