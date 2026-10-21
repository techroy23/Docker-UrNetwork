#!/bin/sh
# Shared runtime for the UrNetwork provider container.
# Sourced by start_userpass.sh and start_authcode.sh.
#
# Exposes:
#   func_bootstrap   - full startup sequence (update, watcher, provider loop)
#   func_check_credentials / func_check_authcode - env validation helpers
#
# The sourcing script sets AUTH_MODE ("userpass" or "authcode") and, for
# authcode, AUTH_CODE before calling func_bootstrap.

APP_DIR="/app"
STATE_DIR="${HOME:-/home/urnetwork}/.urnetwork"
JWT_FILE="$STATE_DIR/jwt"
PROVIDER_JWT_FILE="$STATE_DIR/.provider.jwt"
PROVIDER_LOG="/tmp/urnetwork-provider.log"
PROVIDER_LOG_TAIL_LINES="${PROVIDER_LOG_TAIL_LINES:-10}"
UPDATE_FLAG="/tmp/urnetwork-update-requested"
RELEASES_API_URL="https://api.github.com/repos/urnetwork/build/releases"
VERSION_FILE="$APP_DIR/version.txt"
TMP_DIR="/tmp/urn_update"

# Custom operator endpoints. Both or neither must be set.
API_URL="${API_URL:-}"
CONNECT_URL="${CONNECT_URL:-}"
MAX_MEMORY="${MAX_MEMORY:-}"
VERBOSE="${VERBOSE:-0}"

UPDATE_TIME="${UPDATE_TIME:-00:00}"
PROVIDER_PORT="${PROVIDER_PORT:-8080}"
ALL_OPERATORS="${ALL_OPERATORS:-N}"
AUTO_REGISTER="${AUTO_REGISTER:-N}"
ALLOW_CLIENT_REGISTRATION="${ALLOW_CLIENT_REGISTRATION:-auto}"
HOTKEY_SEED_FILE="${HOTKEY_SEED_FILE:-}"
PROVIDER_ARGS="${PROVIDER_ARGS:-}"
# Treat a token as expired slightly early so a token cannot expire mid-startup.
JWT_SKEW_SECONDS="${JWT_SKEW_SECONDS:-300}"

# === Logging Helper ===
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') >>> UrNetwork >>> $*"
}

# === Provider Log Helpers ===
# Each provider attempt gets a brand new log file. A rejection left over from
# an earlier attempt must never be mistaken for one from the current attempt,
# otherwise the restart logic re-authenticates forever without the provider
# ever running.
func_reset_provider_log() {
    rm -f "$PROVIDER_LOG" 2>/dev/null || true
    : > "$PROVIDER_LOG" 2>/dev/null || true
}

# Print the tail of the provider log with the usual timestamped prefix so the
# failing lines are visible in the container logs.
func_show_provider_log_tail() {
    lines="${1:-$PROVIDER_LOG_TAIL_LINES}"
    if [ -s "$PROVIDER_LOG" ]; then
        log "[DEBUG] Last $lines lines of $PROVIDER_LOG:"
        tail -n "$lines" "$PROVIDER_LOG" 2>/dev/null | while IFS= read -r line; do
            log "[DEBUG]   $line"
        done
    else
        log "[DEBUG] $PROVIDER_LOG is empty"
    fi
}

# The rejection itself can be older than the tail window (the provider keeps
# logging while it shuts down), so print the matching lines explicitly too.
func_show_provider_log_rejection() {
    grep -nE 'jwt rejected by the api|"event":"rejected"' "$PROVIDER_LOG" 2>/dev/null \
        | tail -n 5 | while IFS= read -r line; do
            log "[DEBUG]   match: $line"
        done
}

# === Endpoint Validation ===
func_check_endpoints() {
    if [ -n "$API_URL" ] && [ -z "$CONNECT_URL" ]; then
        log "[ERROR] API_URL is set but CONNECT_URL is not"
        log "[ERROR] Set both API_URL and CONNECT_URL, or neither"
        exit 1
    fi
    if [ -z "$API_URL" ] && [ -n "$CONNECT_URL" ]; then
        log "[ERROR] CONNECT_URL is set but API_URL is not"
        log "[ERROR] Set both API_URL and CONNECT_URL, or neither"
        exit 1
    fi
    if [ -n "$API_URL" ]; then
        log "[INFO] Using custom operator endpoints: api=$API_URL connect=$CONNECT_URL"
    fi
}

# === Verbosity ===
func_set_verbose_flag() {
    VERBOSE_FLAG=""
    case "$(printf '%s' "$VERBOSE" | tr '[:upper:]' '[:lower:]')" in
      0|''|no|false|off) ;;
      1|y|yes|true|on|v|-v) VERBOSE_FLAG="-v" ;;
      2|vv|-vv) VERBOSE_FLAG="-vv" ;;
      *)
        log "[ERROR] VERBOSE must be 0, 1 or 2 (or v/vv); got '$VERBOSE'"
        exit 1
        ;;
    esac
}

func_build_auth_flags() {
    AUTH_FLAGS=""
    # --all-operators uses per-operator endpoints and rejects --api_url.
    if [ -n "$API_URL" ] && ! func_bool "$ALL_OPERATORS"; then
        AUTH_FLAGS="--api_url=$API_URL"
    fi
    if [ -n "$VERBOSE_FLAG" ]; then
        AUTH_FLAGS="$AUTH_FLAGS $VERBOSE_FLAG"
    fi
}

# === Boolean Helper ===
func_bool() {
  case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
    y|yes|true|1|on) return 0 ;;
    *) return 1 ;;
  esac
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
    PROVIDER_NAME="urnetwork_${A_SYS_ARCH}_nightly"
}

# === Directory Validation ===
# The provider refuses to create its registration or write the JWT when the
# state directory is owned by another user or writable by group/other:
#
#   panic: registration parent must be owned and not writable by other users
#
# A named volume created by this image inherits the ownership and mode of
# /home/urnetwork/.urnetwork. A bind mount keeps whatever the host has, so a
# `chmod 777` source fails authentication even though the mode allows writes.
# Normalise the state directory here so `-v` and `--mount`, volume and bind,
# all behave the same.
func_state_dir_is_safe() {
    STATE_OWNER="$(stat -c '%u' "$STATE_DIR" 2>/dev/null || echo '')"
    STATE_MODE="$(stat -c '%a' "$STATE_DIR" 2>/dev/null || echo '')"
    [ "$STATE_OWNER" = "$(id -u)" ] || return 1
    case "$STATE_MODE" in
      ''|*[!0-7]*) return 1 ;;
    esac
    # Owner needs rwx; nobody else may write.
    [ $((0$STATE_MODE & 0700)) -eq $((0700)) ] || return 1
    [ $((0$STATE_MODE & 022)) -eq 0 ]
}

func_fix_state_dir() {
    if func_state_dir_is_safe; then
        return 0
    fi

    log "[WARN] State directory $STATE_DIR has unsafe ownership/mode (owner=${STATE_OWNER:-unknown} mode=${STATE_MODE:-unknown}; running as uid $(id -u))"
    log "[WARN] The provider requires it to be owned by the running user and not writable by group/other"

    # Drop the group/other write bits. This alone fixes a world-writable
    # directory that is already owned by the running user.
    chmod -R go-w "$STATE_DIR" 2>/dev/null || true
    chmod 700 "$STATE_DIR" 2>/dev/null || true

    if func_state_dir_is_safe; then
        log "[INFO] Corrected $STATE_DIR ownership/permissions"
        return 0
    fi

    log "[ERROR] Cannot make $STATE_DIR safe for the provider" >&2
    if [ "${STATE_OWNER:-}" = "$(id -u)" ]; then
        log "[ERROR] It is owned by the running user but has the wrong mode or is read-only" >&2
        log "[ERROR] chmod 700 <source>, and make sure the mount is not read-only" >&2
    else
        log "[ERROR] The container runs as uid $(id -u) but the directory is owned by uid ${STATE_OWNER:-unknown}" >&2
        log "[ERROR] chown <source> to $(id -u):$(id -g) and chmod 700 it" >&2
    fi
    log "[ERROR] Do not use 'chmod 777'; the provider rejects world-writable state" >&2
    exit 1
}

func_check_dir() {
    if [ "$(id -u)" = "0" ]; then
        log "[ERROR] Refusing to run the provider as root" >&2
        log "[ERROR] Start the container through /app/entrypoint.sh as the urnetwork user" >&2
        exit 1
    fi
    runtime_uid="$(id -u urnetwork 2>/dev/null || echo '')"
    if [ -n "$runtime_uid" ] && [ "$(id -u)" != "$runtime_uid" ]; then
        log "[ERROR] Unsupported uid $(id -u); the provider runs as urnetwork (uid $runtime_uid)" >&2
        log "[ERROR] Use the image default user, or start with --user 0 to drop via gosu" >&2
        exit 1
    fi
    [ -d "$APP_DIR" ] || {
        log "[ERROR] APP_DIR '$APP_DIR' does not exist." >&2
        exit 1
    }
    cd "$APP_DIR" || {
        log "[ERROR] Cannot cd to '$APP_DIR'." >&2
        exit 1
    }
    mkdir -p "$STATE_DIR" || {
        log "[ERROR] Cannot create STATE_DIR '$STATE_DIR'." >&2
        log "[ERROR] Check the -v / --mount source and its permissions." >&2
        exit 1
    }
    func_fix_state_dir
    # access(2) ignores a read-only mount, so probe with a real file.
    WRITE_TEST="$STATE_DIR/.write-test.$$"
    if ! ( : > "$WRITE_TEST" ) 2>/dev/null; then
        log "[ERROR] State directory $STATE_DIR is not writable by uid $(id -u)" >&2
        log "[ERROR] Expected owner rwx (mode 700); the mount may be read-only" >&2
        exit 1
    fi
    rm -f "$WRITE_TEST"
}

# === Credential Validation ===
func_check_credentials() {
    if [ -z "$USER_AUTH" ] || [ -z "$PASSWORD" ]; then
        log "[ERROR] USER_AUTH or PASSWORD not set"
        log "[ERROR] Please provide both -e USER_AUTH and -e PASSWORD"
        exit 1
    fi
    log "[INFO] Credentials found"
}

func_check_authcode() {
    if [ -z "$AUTH_CODE" ]; then
        log "[ERROR] AUTH=authcode requires an auth code"
        log "[ERROR] Pass it as the first argument or set -e AUTHCODE"
        exit 1
    fi
}

# === Proxy Setup ===
func_check_proxy() {
    log "[INFO] Checking proxy configuration"
    rm -f "$STATE_DIR/proxy" || true
    if [ ! -f "/app/proxy.txt" ]; then
        log "[INFO] No proxy.txt found; skipping proxy"
        return 0
    fi
    log "[INFO] proxy.txt found; adding proxy"
    if func_bool "$ALL_OPERATORS"; then
        # With all operators the provider copies this file into each
        # operator directory itself.
        cp /app/proxy.txt "$STATE_DIR/proxy"
        log "[INFO] proxy.txt copied to $STATE_DIR/proxy"
    else
        "$APP_DIR/$PROVIDER_NAME" proxy add --proxy_file="/app/proxy.txt"
    fi
}

# === JWT Validation ===
# The auth command writes `jwt`. The provider then keeps the durable token in
# `.provider.jwt` and consumes/moves the bootstrap file. Check both, otherwise
# every restart looks unauthenticated and a single-use auth code is exchanged
# again.
func_jwt_payload() {
    cut -d. -f2 "$1" | tr '_-' '/+' | awk '{
        l = length($0) % 4
        if (l == 2) print $0 "=="
        else if (l == 3) print $0 "="
        else print $0
    }'
}

func_jwt_valid_file() {
    jwt_path="$1"
    [ -s "$jwt_path" ] || return 1
    [ "$(awk -F. '{print NF}' "$jwt_path" 2>/dev/null)" = "3" ] || return 1

    payload="$(func_jwt_payload "$jwt_path" 2>/dev/null | base64 -d 2>/dev/null)" || return 1
    [ -n "$payload" ] || return 1

    exp="$(printf '%s' "$payload" | jq -r '.exp // empty' 2>/dev/null)" || return 1
    case "$exp" in
      ''|*[!0-9]*) return 1 ;;
    esac

    now="$(date +%s)"
    [ "$exp" -gt $((now + JWT_SKEW_SECONDS)) ] || return 1

    nbf="$(printf '%s' "$payload" | jq -r '.nbf // empty' 2>/dev/null)"
    case "$nbf" in
      ''|*[!0-9]*) ;;
      *) [ "$nbf" -le "$now" ] || return 1 ;;
    esac
    return 0
}

func_jwt_valid() {
    if [ -s "$JWT_FILE" ] && func_jwt_valid_file "$JWT_FILE"; then
        return 0
    fi
    [ -s "$PROVIDER_JWT_FILE" ] && func_jwt_valid_file "$PROVIDER_JWT_FILE"
}

# === Provider Flags ===
# Sets PROVIDER_FLAGS from the environment. Values are simple tokens; paths
# with spaces are not supported.
func_has_existing_identity() {
    [ -n "$(find "$STATE_DIR" -name '.provider.key' -o -name '.provider*.jwt' 2>/dev/null | head -n 1)" ]
}

func_should_allow_registration() {
    case "$(printf '%s' "$ALLOW_CLIENT_REGISTRATION" | tr '[:upper:]' '[:lower:]')" in
      y|yes|true|1|on) return 0 ;;
      n|no|false|0|off) return 1 ;;
    esac
    # auto: register only when this installation has no retained identity.
    if func_has_existing_identity; then
        return 1
    fi
    return 0
}

func_build_provider_flags() {
    func_set_verbose_flag
    func_build_auth_flags
    PROVIDER_FLAGS=""

    if [ -n "$API_URL" ]; then
        if func_bool "$ALL_OPERATORS"; then
            log "[WARN] ALL_OPERATORS=Y ignores API_URL/CONNECT_URL; each operator uses its own endpoints"
        else
            PROVIDER_FLAGS="$PROVIDER_FLAGS --api_url=$API_URL --connect_url=$CONNECT_URL"
        fi
    fi

    if [ -n "$MAX_MEMORY" ]; then
        PROVIDER_FLAGS="$PROVIDER_FLAGS --max-memory=$MAX_MEMORY"
    fi

    if [ -n "$VERBOSE_FLAG" ]; then
        PROVIDER_FLAGS="$PROVIDER_FLAGS $VERBOSE_FLAG"
    fi

    if func_bool "$ALL_OPERATORS"; then
        PROVIDER_FLAGS="$PROVIDER_FLAGS --all-operators"

        if func_bool "$AUTO_REGISTER"; then
            if [ -z "$HOTKEY_SEED_FILE" ]; then
                log "[ERROR] AUTO_REGISTER=Y requires HOTKEY_SEED_FILE"
                exit 1
            fi
            PROVIDER_FLAGS="$PROVIDER_FLAGS --auto-register"
        fi

        if [ -n "$HOTKEY_SEED_FILE" ]; then
            PROVIDER_FLAGS="$PROVIDER_FLAGS --hotkey_seed_file=$HOTKEY_SEED_FILE"
        fi
    elif func_bool "$AUTO_REGISTER"; then
        log "[WARN] AUTO_REGISTER is only used with ALL_OPERATORS=Y; ignoring it"
    fi

    if [ -n "$PROVIDER_PORT" ] && [ "$PROVIDER_PORT" != "0" ]; then
        PROVIDER_FLAGS="$PROVIDER_FLAGS --port=$PROVIDER_PORT"
    fi

    if func_should_allow_registration; then
        log "[INFO] Registration of a new provider identity is enabled"
        PROVIDER_FLAGS="$PROVIDER_FLAGS --allow-client-registration"
    fi

    if [ -n "$PROVIDER_ARGS" ]; then
        PROVIDER_FLAGS="$PROVIDER_FLAGS $PROVIDER_ARGS"
    fi
}

# === Authentication ===
# Drop the account token and the quarantine marker the provider writes for a
# rejected sign-in (.provider.jwt.rejected = "blocked"). While that marker
# exists the provider exits without signing in, so re-authenticating alone
# never recovers. The provider key, certificate and .provider.jwt are kept, so
# the identity and payout wallet are untouched.
func_clear_auth_state() {
    rm -f "$JWT_FILE"
    rm -f "$PROVIDER_JWT_FILE" 2>/dev/null || true
    rm -f "$STATE_DIR/.provider.jwt.rejected" 2>/dev/null || true
}

# Print the provider's own output whenever authentication fails. Hiding it
# behind DEBUG=true made a permission panic look like a bad or already-used
# auth code, and the single-use warning then pointed in the wrong direction.
func_report_auth_failure() {
    AUTH_FAILURE_KIND="other"
    log "[ERROR] Authentication failed (exit code: $AUTH_EXIT_CODE)" >&2

    if [ -z "$AUTH_OUTPUT" ]; then
        log "[ERROR] The provider produced no output" >&2
        return 0
    fi

    printf '%s\n' "$AUTH_OUTPUT" | while IFS= read -r line; do
        log "[ERROR]   $line" >&2
    done

    case "$AUTH_OUTPUT" in
      *"must be owned and not writable by other users"*)
        AUTH_FAILURE_KIND="permissions"
        log "[ERROR] $STATE_DIR is owned by another user or writable by group/other" >&2
        log "[ERROR] The provider refuses to write its registration/JWT there" >&2
        log "[ERROR] Use chmod 700 (never 777) on the mounted directory" >&2
        ;;
    esac
    return 0
}

func_login_userpass_once() {
    # AUTH_FLAGS is intentionally unquoted to pass each flag separately.
    if AUTH_OUTPUT=$("$APP_DIR/$PROVIDER_NAME" auth --user_auth="$USER_AUTH" --password="$PASSWORD" -f $AUTH_FLAGS 2>&1); then
        AUTH_EXIT_CODE=0
    else
        AUTH_EXIT_CODE=$?
    fi

    if [ "${DEBUG:-false}" = "true" ]; then
        echo "DEBUG: USER_AUTH=$USER_AUTH"
        echo "DEBUG: AUTH_EXIT_CODE=$AUTH_EXIT_CODE"
        echo "DEBUG: AUTH_OUTPUT=$AUTH_OUTPUT"
    fi

    # Check the token this login just wrote, not the durable fallback.
    if [ -s "$JWT_FILE" ] && func_jwt_valid_file "$JWT_FILE"; then
        return 0
    fi

    func_report_auth_failure
    return 1
}

func_login_userpass() {
    if func_jwt_valid; then
        log "[INFO] Existing JWT is valid; skipping login"
        return 0
    fi
    log "[INFO] No valid JWT found; authenticating"

    while :; do
        log "[INFO] Attempting authentication..."
        if func_login_userpass_once; then
            log "[INFO] Authentication successful - JWT written"
            return 0
        fi
        log "[INFO] Will retry authentication in 5 minutes (300 seconds)"
        sleep 300
    done
}

func_login_authcode() {
    if func_jwt_valid; then
        log "[INFO] Existing JWT is valid; skipping auth code exchange"
        return 0
    fi
    log "[INFO] No valid JWT found; exchanging the auth code"

    while :; do
        log "[INFO] Attempting authentication..."
        # AUTH_FLAGS is intentionally unquoted to pass each flag separately.
        if AUTH_OUTPUT=$("$APP_DIR/$PROVIDER_NAME" auth "$AUTH_CODE" -f $AUTH_FLAGS 2>&1); then
            AUTH_EXIT_CODE=0
        else
            AUTH_EXIT_CODE=$?
        fi

        if [ "${DEBUG:-false}" = "true" ]; then
            echo "DEBUG: AUTH_EXIT_CODE=$AUTH_EXIT_CODE"
            echo "DEBUG: AUTH_OUTPUT=$AUTH_OUTPUT"
        fi

        # Check the token this exchange just wrote, not the durable fallback.
        if [ -s "$JWT_FILE" ] && func_jwt_valid_file "$JWT_FILE"; then
            log "[INFO] Authentication successful - JWT written"
            return 0
        fi
        func_report_auth_failure
        if [ "$AUTH_FAILURE_KIND" != "permissions" ]; then
            log "[WARN] Auth codes are single use; if the output above shows the code was already used, restart the container with a fresh AUTHCODE" >&2
        fi
        log "[INFO] Will retry authentication in 5 minutes (300 seconds)"
        sleep 300
    done
}

# Authenticate every listed operator that has no token yet.
func_login_operators_userpass() {
    log "[INFO] Checking operator credentials"
    operators_output="$("$APP_DIR/$PROVIDER_NAME" operators 2>/dev/null || true)"

    printf '%s\n' "$operators_output" | while read -r domain state _rest; do
        [ -n "$domain" ] || continue
        case "$domain" in
          source:|digest:|authenticate) continue ;;
        esac
        [ "$state" = "awaiting" ] || continue

        log "[INFO] Authenticating operator $domain"
        if "$APP_DIR/$PROVIDER_NAME" auth --operator="$domain" \
             --user_auth="$USER_AUTH" --password="$PASSWORD" -f $AUTH_FLAGS >/dev/null 2>&1; then
            log "[INFO] Operator $domain authenticated"
        else
            log "[WARN] Operator $domain authentication failed"
        fi
    done
}

func_ensure_auth() {
    if func_bool "$ALL_OPERATORS"; then
        if func_bool "$AUTO_REGISTER"; then
            log "[INFO] All operators in auto-register mode; skipping account login"
            return 0
        fi
        if [ "$AUTH_MODE" = "userpass" ]; then
            func_login_operators_userpass
        else
            log "[WARN] ALL_OPERATORS=Y with AUTH=authcode does not authenticate operators"
            log "[WARN] Use AUTH=userpass or ALL_OPERATORS=Y with AUTO_REGISTER=Y + HOTKEY_SEED_FILE"
        fi
        return 0
    fi

    if [ "$AUTH_MODE" = "userpass" ]; then
        func_login_userpass
    else
        func_login_authcode
    fi
}

# === Provider Update Check ===
func_check_update() {
    if [ -f "$VERSION_FILE" ]; then
        CURRENT_VERSION="$(cat "$VERSION_FILE")"
    else
        CURRENT_VERSION=""
    fi
    log "[INFO] Current provider version: ${CURRENT_VERSION:-none}"

    page=1
    max_pages=10
    download_url=""
    tag_name=""

    while [ $page -le $max_pages ]; do
        releases_json=$(curl -s "$RELEASES_API_URL?page=$page&per_page=10")
        count=$(echo "$releases_json" | jq 'if type == "array" then length else 0 end')

        [ "$count" -eq 0 ] && break

        i=0
        while [ $i -lt $count ]; do
            tag_name=$(echo "$releases_json" | jq -r ".[$i].tag_name")
            release_url=$(echo "$releases_json" | jq -r ".[$i].url")

            log "[INFO] Checking release: $tag_name"

            release_json=$(curl -s "$release_url")
            download_url=$(echo "$release_json" | jq -r '.assets[] | select(.name | startswith("urnetwork-provider-")) | .browser_download_url')

            if [ -n "$download_url" ]; then
                log "[INFO] Found provider asset in $tag_name"
                log "[INFO] Download URL: $download_url"
                break 2
            fi

            i=$((i + 1))
        done

        page=$((page + 1))
    done

    if [ -z "$download_url" ]; then
        log "[WARN] No urnetwork-provider-*.tar.gz found in any release"
        return 0
    fi

    LATEST_VERSION=$(echo "$tag_name" | sed 's/^v//')
    log "[INFO] Latest provider version: $LATEST_VERSION"
    if [ "$LATEST_VERSION" = "$CURRENT_VERSION" ]; then
        log "[INFO] Already at latest provider version; skipping."
        return 0
    fi

    log "[INFO] Updating provider from ( $CURRENT_VERSION ) to ( $LATEST_VERSION )"
    # -f matches the full command line; the kernel truncates comm to 15 chars,
    # so -x would never match the provider binary name.
    pkill -f "$APP_DIR/$PROVIDER_NAME" 2>/dev/null || log "[INFO] No running provider to stop"
    mkdir -p "$TMP_DIR"
    ARCHIVE="$TMP_DIR/urnetwork-provider_${LATEST_VERSION}.tar.gz"
    curl -sL "$download_url" -o "$ARCHIVE"
    tar -xzf "$ARCHIVE" -C "$TMP_DIR" "linux/${A_SYS_ARCH}/provider" > /dev/null 2>&1
    mv "$TMP_DIR/linux/${A_SYS_ARCH}/provider" "$APP_DIR/$PROVIDER_NAME"
    chmod +x "$APP_DIR/$PROVIDER_NAME"
    echo "$LATEST_VERSION" > "$VERSION_FILE"
    rm -f "$ARCHIVE"
    log "[INFO] Update provider complete"
}

# === Daily Update Watcher (UTC) ===
func_start_update_watcher() {
    case "$UPDATE_TIME" in
      [0-2][0-9]:[0-5][0-9]) ;;
      *)
        log "[ERROR] UPDATE_TIME must be HH:MM in UTC (got '$UPDATE_TIME')"
        exit 1
        ;;
    esac
    # Run the watcher from its own script. A plain `( ... ) &` subshell keeps
    # the parent's argv, so `ps` shows the same start_authcode.sh /
    # start_userpass.sh command line twice and it looks like a double start.
    /bin/sh "$APP_DIR/update_watcher.sh" "$UPDATE_TIME" "$PROVIDER_NAME" "$UPDATE_FLAG" &
    WATCHER_PID=$!
    log "[INFO] Daily update watcher PID $WATCHER_PID (at $UPDATE_TIME UTC)"
}

# === Provider Lifecycle Management ===
func_start_provider() {
    func_build_provider_flags
    failures=0
    rejections=0
    quick_failures=0
    reauths=0

    while :; do
        # Never let output from an earlier run (a rejection in particular)
        # influence this attempt's restart decision.
        func_reset_provider_log
        func_ensure_auth

        # Apply a pending daily update even if the provider was already down.
        if [ -f "$UPDATE_FLAG" ]; then
            rm -f "$UPDATE_FLAG"
            log "[INFO] Update was requested; refreshing the provider"
            func_check_update
        fi

        failures=$((failures+1))
        log "[INFO] Starting UrNetwork (attempt #$failures)"
        BIN_VER="$("$APP_DIR/$PROVIDER_NAME" --version)"
        log "[INFO] Running UrNetwork build v${BIN_VER}"
        [ -n "$PROVIDER_FLAGS" ] && log "[INFO] Provider flags:$PROVIDER_FLAGS"

        started_at="$(date +%s)"
        func_reset_provider_log
        tail -n +1 -f "$PROVIDER_LOG" &
        tail_pid=$!

        # PROVIDER_FLAGS is intentionally unquoted to pass each flag separately.
        "$APP_DIR/$PROVIDER_NAME" provide $PROVIDER_FLAGS >> "$PROVIDER_LOG" 2>&1
        code=$?

        kill "$tail_pid" 2>/dev/null || true
        wait "$tail_pid" 2>/dev/null || true
        uptime=$(( $(date +%s) - started_at ))

        # A daily update stops the provider; apply it and restart.
        if [ -f "$UPDATE_FLAG" ]; then
            rm -f "$UPDATE_FLAG"
            log "[INFO] Update was requested; refreshing the provider"
            func_check_update
            continue
        fi

        # A tampered or expired token is rejected by the API. Drop it so the
        # next pass authenticates again instead of reusing the bad file.
        if grep -qE 'jwt rejected by the api|"event":"rejected"' "$PROVIDER_LOG" 2>/dev/null; then
            rejections=$((rejections+1))
            log "[WARN] Provider rejected the stored token; clearing it and re-authenticating (#$rejections)"
            func_show_provider_log_rejection
            func_show_provider_log_tail "$PROVIDER_LOG_TAIL_LINES"
            func_clear_auth_state
            if [ "$rejections" -ge 3 ]; then
                log "[ERROR] Token rejected repeatedly; waiting 5 minutes"
                rejections=0
                sleep 300
            else
                sleep 10
            fi
            continue
        fi

        # A long healthy run resets the rejection streak so a transient
        # rejection hours ago cannot escalate later restarts.
        if [ "$uptime" -ge 300 ]; then
            rejections=0
        fi

        if [ "$code" -eq 0 ] && [ "$uptime" -ge 60 ]; then
            log "[INFO] UrNetwork exited cleanly."
            break
        fi

        if grep -q 'startup_recovery_required' "$PROVIDER_LOG" 2>/dev/null; then
            log "[ERROR] The provider needs its original identity (startup_recovery_required)"
            log "[ERROR] Restore the $STATE_DIR backup, or set ALLOW_CLIENT_REGISTRATION=Y to register a new identity"
        fi

        # A provider that dies within seconds never finished starting: the
        # stored token is the usual cause. Retry once, then force a login.
        if [ "$uptime" -lt 20 ]; then
            quick_failures=$((quick_failures+1))
            log "[WARN] UrNetwork stopped after ${uptime}s (startup failure #$quick_failures)"
            func_show_provider_log_tail "$PROVIDER_LOG_TAIL_LINES"
            if [ "$quick_failures" -ge 2 ]; then
                quick_failures=0
                if [ "$reauths" -lt 5 ]; then
                    reauths=$((reauths+1))
                    log "[WARN] Clearing JWT and reauthenticating (re-auth #$reauths)"
                    func_clear_auth_state
                    sleep 10
                else
                    log "[ERROR] Repeated startup failures; waiting 5 minutes"
                    sleep 300
                fi
            else
                sleep 5
            fi
            continue
        fi

        log "[WARN] UrNetwork stopped unexpectedly (code=$code, uptime=${uptime}s, attempt #$failures)"
        if [ "$failures" -ge 3 ]; then
            log "[ERROR] Too many failures; clearing JWT and reauthenticating"
            func_clear_auth_state
            failures=0
            sleep 30
        fi
        sleep 60
    done
}

# === Bootstrap Sequence ===
func_bootstrap() {
    umask 077
    func_get_architecture
    func_check_dir
    func_check_endpoints
    func_check_proxy
    log "[NOTICE] It is highly advised to set your payout wallet in the UrNetwork mobile app or website before expecting rewards"
    func_check_update
    func_start_update_watcher
    func_start_provider
}
