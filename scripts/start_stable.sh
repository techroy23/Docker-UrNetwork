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

# Exit immediately if any command fails
set -e

# === Configuration Variables ===
APP_DIR="/app"
JWT_FILE="/root/.urnetwork/jwt"
ENABLE_VNSTAT="${ENABLE_VNSTAT:-true}"
ENABLE_IP_CHECKER="${ENABLE_IP_CHECKER:-false}"
IP_CHECKER_URL="https://raw.githubusercontent.com/techroy23/IP-Checker/refs/heads/main/app.sh"

# === Logging Helper ===
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') >>> UrNetwork >>> $*"
}

# === Directory Validation ===
func_check_dir() {
    [ -d "$APP_DIR" ] || {
        log "[ERROR] APP_DIR '$APP_DIR' does not exist." >&2
        exit 1
    }
    cd "$APP_DIR" || {
        log "[ERROR] Cannot cd to '$APP_DIR'." >&2
        exit 1
    }
}

# === Credential Validation ===
func_check_credentials() {
    if [ -z "$USER_AUTH" ] || [ -z "$PASSWORD" ]; then
        log "[ERROR] USER_AUTH or PASSWORD not set"
        log "[ERROR] Please provide both -e USER_AUTH and -e PASSWORD"
        exit 1
    else
        log "[INFO] Credentials found"
    fi
}

# === Proxy Setup ===
func_check_proxy() {
    log "[INFO] Checking proxy configuration"
    # ls -la ~/.urnetwork/ 2>/dev/null || log "~/.urnetwork/ not found"
    rm -f ~/.urnetwork/proxy
    if [ -f "/app/proxy.txt" ]; then
        log "[INFO] proxy.txt found; adding proxy"
		PROVIDER_BIN="$APP_DIR/urnetwork_${A_SYS_ARCH}_stable"
        "$PROVIDER_BIN" proxy add --proxy_file="/app/proxy.txt"
    else
        log "[INFO] No proxy.txt found; skipping proxy"
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
    log "[INFO] Checking current public IP..."
    if curl -fsSL "$IP_CHECKER_URL" | sh; then
      log "[INFO] IP checker script ran successfully"
    else
      log "[WARN] Could not fetch or execute IP checker script"
    fi
  else
    log "[INFO] IP checker disabled"
  fi
}

# === vnStat Monitoring Setup ===
func_start_vnstat() {
    VNSTAT_LC="$(printf '%s' "$ENABLE_VNSTAT" | tr '[:upper:]' '[:lower:]')"
    if [ "$VNSTAT_LC" = "true" ]; then
        if [ -f /var/lib/vnstat/vnstat.db ]; then
            log "[INFO] vnStat DB already exists (SQLite backend)"
        elif [ -f /var/lib/vnstat/.config ]; then
            log "[INFO] vnStat DB already exists (binary backend)"
        else
            log "[INFO] Initializing vnStat database"
            vnstatd --initdb
        fi
        vnstatd -d --alwaysadd >/dev/null 2>&1
        log "[INFO] vnstatd started"
        httpd -f -p 8080 -h /app &
        log "[INFO] HTTP server started on container port 8080"
    else
        log "[INFO] VNSTAT disabled ..."
    fi
}

# === Authentication (JWT) ===
func_do_login() {
    rm -f "$JWT_FILE"
    log "[INFO] Removed existing JWT (if any)"
    
    PROVIDER_BIN="$APP_DIR/urnetwork_${A_SYS_ARCH}_nightly"
    
    # Retry loop for authentication
    while true; do
        log "[INFO] Sleeping 15s before obtaining new JWT..."
        sleep 15
        
        log "[INFO] Attempting authentication..."
        
        # Capture auth command output for parsing
        AUTH_OUTPUT=$("$PROVIDER_BIN" auth --user_auth="$USER_AUTH" --password="$PASSWORD" -f 2>&1)
        AUTH_EXIT_CODE=$?
        
        # Check for success message in output
        if echo "$AUTH_OUTPUT" | grep -q "Jwt written to"; then
            log "[INFO] Authentication successful - JWT written"
            sleep 5
            
            # Verify JWT file exists as backup check
            if [ -s "$JWT_FILE" ]; then
                log "[INFO] JWT file verified at $JWT_FILE"
                sleep 5
                return 0
            else
                log "[WARN] Success message found but JWT file missing - retrying"
                log "[INFO] Will retry authentication in 1 minutes (60 seconds)..."
                sleep 60
            fi
        else
            # Authentication failed - output exit code and auth output
            log "[ERROR] Authentication failed (exit code: $AUTH_EXIT_CODE)" >&2
            log "[ERROR] Command output: $AUTH_OUTPUT" >&2
            
            log "[INFO] Will retry authentication in 5 minutes (300 seconds)..."
            sleep 300
        fi
    done
}

# === Provider Lifecycle Management ===
func_start_provider(){
    failures=0
    while :; do
        log "[INFO] Starting UrNetwork (attempt #$((failures+1)))"
        PROVIDER_BIN="$APP_DIR/urnetwork_${A_SYS_ARCH}_stable"
		BIN_VER="$($PROVIDER_BIN --version)"
		log "[INFO] Running UrNetwork build v${BIN_VER}"
        "$PROVIDER_BIN" provide
        code=$?
        if [ "$code" -eq 0 ]; then
            log " [INFO] UrNetwork exited cleanly."
            break
        fi
        failures=$((failures+1))
        log "[WARN] UrNetwork crashed (#$failures; code=$code)"
        if [ "$failures" -ge 3 ]; then
            log "[ERROR] Too many crashes; clearing JWT and reauthenticating"
            rm -f "$JWT_FILE"
            func_check_credentials
            failures=0
        fi
        log "[INFO] Waiting 60s before retry"
        sleep 60
    done
}

# === Bootstrap Sequence ===
func_bootstrap() {
    # sh /app/urnetwork_ipinfo.sh
	func_get_architecture
	func_check_dir
	func_check_credentials
    func_check_proxy
    # func_get_ip
    func_start_vnstat
    func_do_login
    func_start_provider
}

# === Main Entrypoint ===
main() {
    func_bootstrap
}

main "$@"
